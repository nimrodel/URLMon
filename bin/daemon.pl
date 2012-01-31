use strict;
use DBI;
use LWP::Simple;
use DateTime;

use threads;
use threads::shared;

sub ReadConf;
sub InitURLHash;
sub GetCurrentDatetime;
sub CheckMsgQueue;
sub UpdateURLState;
sub UpdateLog;
sub PrepareMail;
sub SendMail;
sub SendMailToSubscribers;
sub CheckMsgQueue;
sub Run;


######################################## Main ########################################

#shared queue: Main thread will push messages, SendMail thread will shift;
my @msg_queue;
share(@msg_queue);

my ($database, $user, $pass ) = ReadConf;

my $dsn = "dbi:mysql:$database:localhost:3306";
my $dbh = DBI->connect( $dsn,
						$user,                          # user
						$pass,                          # password
						{ RaiseError => 1 },         # complain if something goes wrong
						) or die $DBI::errstr; 

my $sth_selectall = $dbh->prepare("SELECT id, url, int_sec, IFNULL(TIME_TO_SEC(TIMEDIFF(NOW(), l_checked )), -1) from urls;");
my $sth_getsubscribers = $dbh->prepare("SELECT DISTINCT mail, type FROM notifications WHERE url_id=? AND type IN (?, 2)");
my $sth_getlastlogs = $dbh->prepare("SELECT DISTINCT url_id, dt, status FROM logs l WHERE dt = (SELECT MAX(dt) FROM logs sl WHERE l.url_id = sl.url_id);");
my $sth_updatelogs = $dbh->prepare("INSERT INTO logs values (?, ?, ?);");
my $sth_updateurlstate = $dbh->prepare("UPDATE urls SET l_checked=? WHERE id=?");

#RUN:
Run();

######################################################################################

sub ReadConf
{
	open(CONF, "<", "../etc/db.conf") or die "Could not open file '../etc/db.conf': $!";
	my ($database, $user, $pass, $mailconf );
	while(<CONF>)
	{
		if( $_ =~ m/^dbname=.*/)
		{
		$database = substr($_, 7, -1); #print $database."\n";
		}
		elsif( $_ =~ m/^user=.*/)
		{
			$user = substr($_, 5, -1); #print $user."\n";
		}
		elsif( $_ =~ m/^pass=.*/)
		{
			$pass = substr($_, 5, -1);  #print $pass."\n";
		}
	}
	close(CONF);
	return ($database, $user, $pass );
}

sub InitURLHash
{
	$sth_getlastlogs->execute();										
	my @result = @{$sth_getlastlogs->fetchall_arrayref()};

	map { $_->[0] => [$_->[1], $_->[2]]} @result;
}

sub GetCurrentDatetime
{
	my $dt = DateTime->now('time_zone' => DateTime::TimeZone->new( name => 'local' ));
	($dt->ymd." ".$dt->hms);
}

sub CheckURLState
{
	my $url = @_[0];
	1 if (head($url)) or 0;
}

sub CheckMsgQueue
{
	while(1)
	{
		if( @msg_queue )
		{
			#print "We have sth on the queue, let's get it and send it!\n";
			lock(@msg_queue);
			my @msg = @{shift(@msg_queue)};
			SendMail(@msg);
		}
	}
}

sub UpdateLog
{
	my ($id, $status, $time ) = @_;	
	$sth_updatelogs->execute($time, $id, $status);
}

sub UpdateURLState
{
	my ($id, $time ) = @_;		
	$sth_updateurlstate->execute($time, $id);
}


sub SendMailToSubscribers
{
	my ($id, $url, $state, $time) = @_;
	$sth_getsubscribers->execute($id, $state);
	
	while( my @row = $sth_getsubscribers->fetchrow_array() )
	{
		my ($mail,$subscription) = @row;
		#print "Sending mail to $mail\n";
			
		#seems that nested structures can be shared only if the elements are shared as well
		my @msg : shared;
		@msg = PrepareMail( $mail, $url, $state, $time, $subscription );
		{
			lock(@msg_queue);
			push(@msg_queue, \@msg);
		}
	}
}

sub PrepareMail
{
	my ($to, $url, $state, $time, $subscription) = @_;
	my $strsubscr;
	my $strstate;
	
	if( $state == 0){
		$strsubscr = $strstate = "down";
	}
	elsif( $state == 1){
		$strsubscr = $strstate = "up";
	}
	
	if( $subscription == 2 ){
		$strsubscr = "up or down";
	}
	
	my $from = "notification\@urlmon";
	my $to = "gabriela.tzanova\@gmail.com";
	my $subject = "URL Monitor Notification: Status update";
	my $message = "Hello, \n
You have subscribed to receive a notification when the server at '$url' goes $strsubscr.\n
Currently the server is $strstate.
\n\n
Last check: $time";
				  	
	return ($from, $to, $subject, $message);
}
sub SendMail
{
	my ($from, $to, $subject, $message) = @_;
	
	my $sendmail = '/usr/lib/sendmail';
 	open(MAIL, "|$sendmail -oi -t");
 		print MAIL "From: $from\n";
 		print MAIL "To: $to\n";
 		print MAIL "Subject: $subject\n\n";
 		print MAIL "$message\n";
 	close(MAIL);
}

sub Run
{
	my %url_to_state = InitURLHash();
	my $run = 1;
	my $thr_sendmail = threads->create( \&CheckMsgQueue );
	while ($run)
	{
		$sth_selectall->execute();

		while( my @row = $sth_selectall->fetchrow_array() )
		{
			(my $id, my $url, my $interval, my $last_checked ) = @row; 

			print("id: $id, url: $url, interval: $interval, last check: $last_checked\n");
			
			if( $last_checked == -1 or $last_checked >= $interval )
			{
				my $now = GetCurrentDatetime; 
				my $state = CheckURLState($url);
				UpdateURLState( $id, $now );
				
				#log if needed 			
				if( !defined($url_to_state{$id}) or $url_to_state{$id}->[1] != $state )
				{
					UpdateLog( $id, $state, $now );
					$url_to_state{$id} = [$now, $state];
					
					SendMailToSubscribers($id, $url, $state, $now);
				}
			}
		}
		$run++;
		if( $run == 30 )
		{
			$run = 0;
		}
		#there will be at least 1 second pause between every db check
		sleep(1);
	}
	$thr_sendmail->join;
}
