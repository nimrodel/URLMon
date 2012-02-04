#!/usr/bin/perl
use strict;
use DBI;
use CGI;
use Regexp::Common::URI;


########## SUB DECLARATIONS ##########

## general purpose
sub DBconnect;
sub Trim($);
sub IsNumeric($);

## modify data
sub AddURL;
sub DeleteURL;

sub AddURLToGroup;
sub RemoveURLFromGroup;

sub AddNotification;
sub EditNotification;
sub DeleteNotification;

sub SetInterval;

## HTML
sub ShowHeader;
sub ShowMenu;
sub ShowUrls;
sub ShowGroups;
sub ShowFooter;
sub ExecFunc;


########## VAR DEFINITIONS ##########

my $cgi = CGI->new;
my $dbh = DBconnect();
my $mode;
my $drop;
my $id;
my $func;
my $args;


## prepared queries
#add
my $sth_add_url = $dbh->prepare( "INSERT INTO urls (url, int_sec) VALUES(?, ?);");
my $sth_add_url_to_group = $dbh->prepare( "INSERT INTO groups VALUES( ?, ? );");
my $sth_add_notification = $dbh->prepare("INSERT INTO notifications VALUES (?, ?, ?);");

#delete
my $sth_del_url_from_group = $dbh->prepare( "DELETE FROM groups WHERE name = ? AND url_id = ?;");
my $sth_del_url_from_all_groups = $dbh->prepare( "DELETE FROM groups WHERE url_id = ?;" );
my $sth_remove_url_logs = $dbh->prepare("DELETE FROM logs WHERE url_id=?");
my $sth_remove_url_notifications = $dbh->prepare("DELETE FROM notifications WHERE url_id=?;");
my $sth_del_url = $dbh->prepare("DELETE FROM urls WHERE id = ?;");
my $sth_del_notification = $dbh->prepare("DELETE FROM notifications WHERE url_id=? AND mail=?;");

#get
my $sth_get_urls = $dbh->prepare("SELECT * FROM urls ORDER BY id");
my $sth_get_url_status = $dbh->prepare("SELECT status FROM logs L WHERE L.url_id = ? AND L.dt = (SELECT MAX(ML.dt) FROM logs ML WHERE L.url_id = ML.url_id)");
my $sth_get_url_by_id = $dbh->prepare("SELECT * FROM urls WHERE id = ?");
my $sth_get_url_by_group = $dbh->prepare("SELECT * FROM urls U WHERE id IN (SELECT url_id FROM groups WHERE name = ?);");
my $sth_get_groups = $dbh->prepare("SELECT DISTINCT name FROM groups;");
my $sth_get_notifications_by_urlid = $dbh->prepare("SELECT * FROM notifications WHERE url_id = ?;");
my $sth_get_logs_by_urlid = $dbh->prepare("SELECT * FROM logs WHERE url_id = ? ORDER by dt;");
my $sth_get_groups_by_urlid = $dbh->prepare("SELECT name FROM groups WHERE url_id = ?;");

#check
my $sth_check_url_in_group = $dbh->prepare("SELECT * FROM groups WHERE url_id=? AND name=?;");

#set
my $sth_set_interval_by_id = $dbh->prepare("UPDATE urls SET int_sec = ? WHERE id = ?");
my $sth_edit_notification = $dbh->prepare("UPDATE notifications SET type=? WHERE url_id=? AND mail=?;");



########## MAIN ##########

## get input parameters (from GET method)

if(defined($cgi->param('urls')))
{
	$mode = "urls";
	if(IsNumeric($cgi->param('urls')))
	{
		$id = $cgi->param('urls');
	}
}
elsif(defined($cgi->param('groups')))
{
	$mode = "groups";
	if(IsNumeric($cgi->param('groups')))
	{
		$id = $cgi->param('groups');
	}
}
elsif(defined($cgi->param('func')))
{
	$mode = "func";
	$func = $cgi->param('func');
	$args = $cgi->param('args');
}
else
{
	$mode = "urls";
}

## Show page

if($mode eq 'urls' or $mode eq 'groups')
{
	ShowHeader;
	ShowMenu($mode);
	
	if($mode eq 'urls')
	{
		ShowUrls($id);
	}
	else
	{
		ShowGroups($id);
	}
	
	ShowFooter;
}
elsif($mode eq 'func')
{
	ExecFunc($func, $args);
}


########## SUB DEFINITIONS ##########

sub DBconnect
{
	open(CONF, "<", "../urlmon.cfg") or die "Could not open config: $!";
	my ($database, $user, $pass);
	while( <CONF> )
	{
		chomp;
		my @row = split( '=', $_ );

		$database = $row[1] if $row[0] eq "dbname";
		$user = $row[1] if $row[0] eq "user";
		$pass = $row[1] if $row[0] eq "pass";
	}
	
	close(CONF);

	my $dsn = "dbi:mysql:$database:localhost:3306";
	my $dbh = DBI->connect( $dsn,
							$user,                        # user
							$pass,                    # password
							{ RaiseError => 1,
							  AutoCommit => 0},        
							) or die $DBI::errstr; 
}

sub Trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub IsNumeric($)
{
	my $t = shift;
	Trim($t) =~ /^(\d+)$/;
 
}

sub ShowHeader
{
	print $cgi->header(-encoding => "utf8", -charset=>"utf8");
	print $cgi->start_html(
		-title=>'URLmon',
		-style=>{'src'=>'/css/style.css'},
		-script=>{-type=>'javascript', -src=>'/js/urlmon.js'}
		);
}

sub ShowFooter
{
	print $cgi->end_html();
}

sub ShowMenu($)
{
	my $mode = shift;
	print "\t".$cgi->div(
					{ -class=>"menu" },
					"\n\t\t".
					$cgi->a( { -href=>'?urls=',   -class=> ( $mode eq "urls" ? 'selected' : "" ) }, "URLs" ).
					$cgi->a( { -href=>'?groups=', -class=> ( $mode eq "groups" ? 'selected' : "" ) }, "Groups" ).
					"\t\n\t"
				)."\n";
}

sub ShowUrls
{
	## new URL table
	print "\t".$cgi->start_table( {	-class=>'list' } )."\n";
	
	print "\t".$cgi->start_Tr( { -class=>"header" }	)."\n";
	print "\t\t".$cgi->td( "Address" )."\n";
	print "\t\t".$cgi->td( { -width=>"100" }, "Interval" )."\n";
	print "\t\t".$cgi->td( { -width=>"105" }, "&nbsp;" )."\n";
	print "\t".$cgi->end_Tr()."\n";
	
	print "\t".$cgi->start_Tr( { -class=>"mainline" } )."\n";
	print "\t\t".$cgi->td( $cgi->input( { -id=>"new_url", -type=>"text", -value=>"http://"} ) )."\n";
	print "\t\t".$cgi->td( $cgi->input( { -id=>"new_interval", -type=>"text" } ) )."\n";
	print "\t\t".$cgi->td( $cgi->button( { -value=>"Add URL", -onClick=>"javascript: AddURL()" } ) )."\n";
	print "\t".$cgi->end_Tr()."\n";
		
	print "\t".$cgi->end_table()."\n\n";
	
	
	## list existing URLs
	$sth_get_urls->execute();
	
	print "\t".$cgi->start_table( { -class=>'list' } )."\n";
		
	## header row
	print "\t".$cgi->start_Tr( { -class=>"header" } )."\n";
	print "\t\t".$cgi->td( { -width=>"30", -align=>"center" }, "ID" )."\n";
	print "\t\t".$cgi->td( "Address" )."\n";
	print "\t\t".$cgi->td( { -width=>"80" }, "Interval" )."\n";
	print "\t\t".$cgi->td( { -width=>"80" }, "Status" )."\n";
	print "\t\t".$cgi->td( { -width=>"200" }, "Last checked" )."\n";
	print "\t\t".$cgi->td( { -width=>"105" }, "&nbsp;" )."\n";
	print "\t".$cgi->end_Tr()."\n";
	
	while( my @row = $sth_get_urls->fetchrow_array() )
	{
		$sth_get_url_status->execute($row[0]);
		
		my @status = $sth_get_url_status->fetchrow_array();
		
		## show URL header line
		print "\t".$cgi->start_Tr({-class=>"mainline"})."\n";
		print "\t\t".$cgi->td( { -align=>"center", -rowspan=>"4" }, $row[0] )."\n";
		print "\t\t".$cgi->td( $row[1] )."\n";
		print "\t\t".$cgi->td(
						$cgi->span( { -id=>"span_interval_".$row[0] }, $row[2] ).
						$cgi->input( { -id=>"edit_interval_".$row[0], -type=>"text", -class=>"invisible", -value=>$row[2] } )
					)."\n";
		print "\t\t".$cgi->td(
						{ -class=>( !exists($status[0]) ? "status_na" : ($status[0] == 0 ? "status_offline" : "status_online" ) ) },
						( !exists($status[0]) ? "N/A" : ($status[0] == 0 ? "Offline" : "Online" ) )
					)."\n";
		print "\t\t".$cgi->td( $row[3] )."\n";
		print "\t\t".$cgi->td(
						$cgi->button( { -id=>"edit_button_".$row[0], -class=>"button_80", -value=>"Edit", -onClick=>"javascript: EditURL($row[0])" } ).
						$cgi->button( {	-class=>"button_20", -value=>"X", -onClick=>"javascript: RemoveURL($row[0])" } )
					)."\n";
		print "\t".$cgi->end_Tr()."\n";
		
		
		## show Subscribers
		print "\t".$cgi->start_Tr( { -class=>"detailline" } )."\n";
		print "\t\t".$cgi->start_td( { -colspan=>"5" } )."\n";
		print "\t\t\t".$cgi->a(
							{ -href=>"javascript: ToggleByID('notif_$row[0]')" },
							$cgi->img( { -id=>"notif_$row[0]_image", -src=>"../images/plus.png", -alt=>"" } ).
							" Subscribers"
						)."\n";
						
		$sth_get_notifications_by_urlid->execute($row[0]);
				print "\t\t\t".$cgi->start_div( { -id=>"notif_$row[0]", -class=>( $id eq $row[0] ? "" : " invisible" ) } )."\n";
		
		print "\t\t\t\t".$cgi->start_table( { -class=>"sublist" } )."\n";
		my $notif_id = 0;
		while( my @notifications = $sth_get_notifications_by_urlid->fetchrow_array() )
		{
			print "\t\t\t\t".$cgi->start_Tr()."\n";
			print "\t\t\t\t\t".$cgi->td( $notifications[1] )."\n";
			print "\t\t\t\t\t".$cgi->td(
									$cgi->Select( { -id=>"notif_$row[0]_type_$notif_id", -disabled=>"disabled" },
										'<option value="0"'.( $notifications[2] == 0 ? ' selected="selected"' : '' ).">on going down</option>".
										'<option value="1"'.( $notifications[2] == 1 ? ' selected="selected"' : '' ).">on going up</option>".
										'<option value="2"'.( $notifications[2] == 2 ? ' selected="selected"' : '' ).">on going up or down</option>"
									)	
								)."\n";
			print "\t\t\t\t\t".$cgi->td(
									$cgi->button( { -id=>"notif_$row[0]_edit_button_$notif_id", -class=>"button_80", -value=>"Edit", -onClick=>"javascript: EditNotification($row[0],$notif_id,'$notifications[1]')" } ).
									$cgi->button( {	-class=>"button_20", -value=>"X", -onClick=>"javascript: RemoveNotification($row[0],'$notifications[1]')" } )
								)."\n";
			print "\t\t\t\t".$cgi->end_Tr()."\n";
			$notif_id++;
		}
		print "\t\t\t\t".$cgi->start_Tr()."\n";
		print "\t\t\t\t\t".$cgi->td( { -width=>"auto" },  $cgi->input( { -id=>"new_notif_mail_$row[0]", -type=>"text"	} ) )."\n";
		print "\t\t\t\t\t".$cgi->td(
								{ -width=>"200px" },
								$cgi->Select(
									{ -id=>"new_notif_type_$row[0]" },
									$cgi->option("on going down").
									$cgi->option("on going up").
									$cgi->option("on going up or down")
								)
							)."\n";
		print "\t\t\t\t\t".$cgi->td( { -width=>"100px" }, $cgi->button( { -value=>"Add", -onClick=>"javascript: AddNotification($row[0])" } ) )."\n";
		print "\t\t\t\t".$cgi->end_Tr()."\n";
		
		print "\t\t\t\t".$cgi->end_table()."\n";
		print "\t\t\t".$cgi->end_div()."\n";
		
		print "\t\t".$cgi->end_td()."\n";
		print "\t".$cgi->end_Tr()."\n";
		
		
		## show Groups
		print "\t".$cgi->start_Tr( { -class=>"detailline" } )."\n";
		print "\t\t".$cgi->start_td( { -colspan=>"5" } )."\n";
		print "\t\t\t".$cgi->a(
							{ -href=>"javascript: ToggleByID('group_$row[0]')" },
							$cgi->img( { -id=>"group_$row[0]_image", -src=>"../images/plus.png", -alt=>"" } ).
							" Groups"
						)."\n";
		
		$sth_get_groups_by_urlid->execute($row[0]);
		print "\t\t\t".$cgi->start_div( { -id=>"group_$row[0]", -class=>( $id eq $row[0] ? "" : " invisible" ) } )."\n";
		
		print "\t\t\t\t".$cgi->start_table( { -class=>"sublist" } )."\n";
		while( my @groups = $sth_get_groups_by_urlid->fetchrow_array() )
		{
			print "\t\t\t\t".$cgi->start_Tr()."\n";
			print "\t\t\t\t\t".$cgi->td( $groups[0] )."\n";
			print "\t\t\t\t\t".$cgi->td( $cgi->button( { -value=>"Remove", -onClick=>"javascript: RemoveGroup($row[0],'$groups[0]')" } ) )."\n";
			print "\t\t\t\t".$cgi->end_Tr()."\n";
		}
		print "\t\t\t\t".$cgi->start_Tr()."\n";
		print "\t\t\t\t\t".$cgi->td( { -width=>"auto" },  $cgi->input( { -id=>"new_group_$row[0]", -type=>"text"	} ) )."\n";
		print "\t\t\t\t\t".$cgi->td( { -width=>"100px" }, $cgi->button( { -value=>"Add", -onClick=>"javascript: AddGroup($row[0])" } ) )."\n";
		print "\t\t\t\t".$cgi->end_Tr()."\n";
		
		print "\t\t\t\t".$cgi->end_table()."\n";
		print "\t\t\t".$cgi->end_div()."\n";
		
		print "\t\t".$cgi->end_td()."\n";
		print "\t".$cgi->end_Tr()."\n";
		
		## show Logs
		print "\t".$cgi->start_Tr( { -class=>"detailline" } )."\n";
		print "\t\t".$cgi->start_td( { -colspan=>"5" } )."\n";
		print "\t\t\t".$cgi->a(
							{ -href=>"javascript: ToggleByID('log_$row[0]')" },
							$cgi->img( { -id=>"log_$row[0]_image", -src=>"../images/plus.png", -alt=>"" } ).
							" Logs"
						)."\n";
		
		$sth_get_logs_by_urlid->execute($row[0]);
		print "\t\t\t".$cgi->start_div( { -id=>"log_$row[0]", -class=>"invisible" } )."\n";
		
		print "\t\t\t\t".$cgi->start_table( { -class=>"sublist" } )."\n";
		while( my @logs = $sth_get_logs_by_urlid->fetchrow_array() )
		{
			print "\t\t\t\t".$cgi->start_Tr()."\n";
			print "\t\t\t\t\t".$cgi->td( $logs[0] )."\n";
			print "\t\t\t\t\t".$cgi->td( { -class=>( $logs[2] == -1 ? "status_na" : ($logs[2] == 0 ? "status_offline" : "status_online" ) )	 }, $logs[2] == 0 ? "Offline [Down]" : "Online [Up]" )."\n";
			print "\t\t\t\t".$cgi->end_Tr()."\n";
		}
		print "\t\t\t\t".$cgi->start_Tr()."\n";
		print "\t\t\t\t\t".$cgi->td( { -colspan=>"2" } )."\n";
		print "\t\t\t\t".$cgi->end_Tr()."\n";
	
		print "\t\t\t\t".$cgi->end_table()."\n";
		print "\t\t\t".$cgi->end_div()."\n";
		
		print "\t\t".$cgi->end_td()."\n";
		print "\t".$cgi->end_Tr()."\n";
	}
	
	print "\t".$cgi->end_table()."\n";
}

sub ShowGroups
{
	## list groups
	my @groups;
	my @status;
	my $i = 0;
	my $j = 0;
	
	$sth_get_groups->execute();
	
	while( my @row = $sth_get_groups->fetchrow_array() )
	{
		$groups[$i] = { "name"=>$row[0], "urls"=>[] };
		
		$sth_get_url_by_group->execute($row[0]);
		$j = 0;
		while( my @url = $sth_get_url_by_group->fetchrow_array() )
		{
			$groups[$i]->{"urls"}->[$j] = { "id"=>$url[0], "url"=>$url[1], "interval"=>$url[2], "last_check"=>$url[3] };
			
			$sth_get_url_status->execute($url[0]);
			my @status = $sth_get_url_status->fetchrow_array();
			$groups[$i]->{"urls"}->[$j]->{"status"} = @status ? $status[0] : -1;
			
			$j++;
		}
		
		$i++;
	}



	print "\t".$cgi->start_table( { -class=>'list' } )."\n";

	## header row
	print "\t".$cgi->start_Tr( { -class=>"header" } )."\n";
	print "\t\t".$cgi->td( "Name" )."\n";
	print "\t\t".$cgi->td( "Address" )."\n";
	print "\t\t".$cgi->td( "Interval" )."\n";
	print "\t\t".$cgi->td( "Status" )."\n";
	print "\t\t".$cgi->td( "Last checked" )."\n";
	print "\t".$cgi->end_Tr()."\n";

	my @row;
	
	for($i = 0; $i < @groups; $i++)
	{
		my $url_cnt= @{$groups[$i]->{"urls"}};
		
		for($j = 0; $j < $url_cnt; $j++)
		{
			my $status = $groups[$i]->{"urls"}->[$j]->{"status"};
			print "\t".$cgi->start_Tr( { -class=>"mainline" } )."\n";
			if($j == 0)
			{
				print "\t\t".$cgi->td( { -rowspan=>$url_cnt*2 }, $groups[$i]->{"name"} )."\n";
			}
			
			print "\t\t".$cgi->td( $groups[$i]->{"urls"}->[$j]->{"url"} )."\n";
			print "\t\t".$cgi->td( $groups[$i]->{"urls"}->[$j]->{"interval"} )."\n";
			print "\t\t".$cgi->td(
							{ -class=>( $status == -1 ? "status_na" : ($status == 0 ? "status_offline" : "status_online" ) ) },
							( $status == -1 ? "N/A" : ($status == 0 ? "Offline" : "Online" ) )
						)."\n";
			print "\t\t".$cgi->td( $groups[$i]->{"urls"}->[$j]->{"last_check"} )."\n";
			
			print "\t".$cgi->end_Tr()."\n";
			
			
			print "\t".$cgi->start_Tr( { -class=>"mainline" } )."\n";
			print "\t\t".$cgi->start_td( { -colspan=>4 } )."\n";
			print "\t\t\t".$cgi->a(
							{ -href=>"javascript: ToggleByID('log_".$i."_".$groups[$i]->{"urls"}->[$j]->{"id"}."')" },
							$cgi->img( { -id=>"log_".$i."_".$groups[$i]->{"urls"}->[$j]->{"id"}."_image", -src=>"../images/plus.png", -alt=>"" } ).
							" Logs"
						)."\n";
			
			$sth_get_logs_by_urlid->execute($groups[$i]->{"urls"}->[$j]->{"id"});
			print "\t\t\t".$cgi->start_div( { -id=>"log_".$i."_".$groups[$i]->{"urls"}->[$j]->{"id"}, -class=>"invisible" } )."\n";
			
			print "\t\t\t\t".$cgi->start_table( { -class=>"sublist" } )."\n";
			while( my @logs = $sth_get_logs_by_urlid->fetchrow_array() )
			{
				print "\t\t\t\t".$cgi->start_Tr()."\n";
				print "\t\t\t\t\t".$cgi->td( $logs[0] )."\n";
				print "\t\t\t\t\t".$cgi->td( { -class=>( $logs[2] == -1 ? "status_na" : ($logs[2] == 0 ? "status_offline" : "status_online" ) )	 }, $logs[2] == 0 ? "Offline [Down]" : "Online [Up]" )."\n";
				print "\t\t\t\t".$cgi->end_Tr()."\n";
			}
			print "\t\t\t\t".$cgi->start_Tr()."\n";
			print "\t\t\t\t\t".$cgi->td( { -colspan=>"2" } )."\n";
			print "\t\t\t\t".$cgi->end_Tr()."\n";
		
			print "\t\t\t\t".$cgi->end_table()."\n";
			print "\t\t\t".$cgi->end_div()."\n";

			print "\t\t".$cgi->end_td()."\n";
			print "\t".$cgi->end_Tr()."\n";
		}
	}
	
	print "\t".$cgi->end_table()."\n";
}

sub ExecFunc
{
	my @row;
	my ($func, $args) = @_;
	my @args = split(/\|/, $args);

	print $cgi->header();
	
#	print $func."\n";
#	print "$_\n" foreach(@args);
	if($func eq "add_group")
	{
		AddURLToGroup(@args) or die;
	}
	elsif($func eq "remove_group")
	{
		RemoveURLFromGroup(@args) or die;
	}
	elsif($func eq "set_interval")
	{
		SetInterval(@args) or die;
	}
	elsif($func eq "remove_url")
	{
		DeleteURL($args[0]) or die;
	}
	elsif ($func eq "add_url")
	{
		AddURL(@args) or die;
	}
	elsif ($func eq "add_notification")
	{
		AddNotification(@args) or die;
	}
	elsif ($func eq "set_notif_type" )
	{
		EditNotification(@args) or die;
	}
	elsif ($func eq "remove_notification" )
	{
		DeleteNotification(@args) or die; 
	}
	else
	{
		print "Unknown function call: $func";
		die;
	}
	
	die;
}

sub AddURL
{
	my ($url, $interval) = @_;
	
	$url =~ /$Regexp::Common::URI::RE{URI}/ or print "Invalid URL!" and die;
	IsNumeric($interval) and $interval > 0 or print "Invalid interval: $interval" and die;
	eval
	{
		$sth_add_url->execute($url, $interval);
		$dbh->commit;
		print "URL $url successfully added.";
	} 
	or do
	{
		eval{$dbh->rollback};
		print "Unable to add URL $url." and die; 
	}
}

sub AddURLToGroup
{
	my ($urlid, $group) = @_;
	
	$group or print "Empty group name" and die;
	IsNumeric($urlid) or print "Invalid URL ID : $urlid" and die;
	
	$sth_get_url_by_id->execute($urlid);
	
	$sth_get_url_by_id->fetchrow_array() or print "URL ID does not exist: $urlid" and die;
	
	$sth_check_url_in_group->execute($urlid, $group);
	!$sth_check_url_in_group->fetchrow_array() or print "URL already in group $group" and die; 

	$sth_add_url_to_group->execute($group, $urlid);
	
	print "URL successfully added to group $group";
}

sub RemoveURLFromGroup
{
	my ($urlid, $group) = @_;
	IsNumeric($urlid) or print "Invalid URL ID : $urlid" and die;

	$sth_get_url_by_id->execute($urlid);
	$sth_get_url_by_id->fetchrow_array() or print "URL ID does not exist: $urlid" and die;

	eval
	{
		$sth_del_url_from_group->execute($group, $urlid);
		$dbh->commit;
		print "URL successfully removed from group $group";
		
	} or print "Unable to remove URL from group $group." and die;
}

sub DeleteURL
{
	my $urlid = shift;
	IsNumeric($urlid) or print "Invalid URL ID : $urlid" and die;
	
	eval
	{
		$sth_remove_url_logs->execute($urlid) or 0;
		$sth_remove_url_notifications->execute($urlid) or 0;
		$sth_del_url_from_all_groups->execute($urlid) or 0;
		$sth_del_url->execute($urlid) or 0;
		$dbh->commit or 0;
		print "URL successfully removed";
	}
	or do
	{
		eval{$dbh->rollback};
	}
}

sub SetInterval
{
	my ($urlid, $interval) = @_;
	IsNumeric($urlid) or print "Invalid URL ID : $urlid" and die;
	
	$sth_get_url_by_id->execute($urlid);
	$sth_get_url_by_id->fetchrow_array() or print "URL ID does not exist: $urlid" and die;
	
	IsNumeric($interval) and $interval > 0 or print "Invalid interval : $interval" and die;
	
	eval
	{
		$sth_set_interval_by_id->execute($interval, $urlid);
		$dbh->commit;
		print "Interval successfully updated";
	}
	or do
	{
		eval{$dbh->rollback};
		print "Error updating interval: $@" and die;
	};
}

sub AddNotification
{
	my ($urlid, $mail, $type) = @_;
	IsNumeric($urlid) or print "Invalid URL ID : $urlid" and die;
	
	IsNumeric($type) and $type >= 0 and $type <= 2 
		or print "Invalid notification type: $type" and die;
		
	$mail =~ /^([0-9a-zA-Z]([-\.\w]*[0-9a-zA-Z])*@([0-9a-zA-Z][-\w]*[0-9a-zA-Z]\.)+[a-zA-Z]{2,9})$/ 
		or print "Invalid email address: $mail" and die;
	
	eval
	{
		$sth_add_notification->execute($urlid, $mail, $type);
		$dbh->commit;
		print "Notification successfully added";
	}
	or do
	{
		eval{$dbh->rollback};
		print "Error adding notification: $@" and die;
	};
}

sub EditNotification
{
	my ($urlid, $mail, $type) = @_;
	IsNumeric($urlid) or print "Invalid URL ID : $urlid" and die;
	
	IsNumeric($type) and $type >=- 0 and $type <= 2 
		or print "Invalid notification type: $type" and die;
	
	eval
	{
		$sth_edit_notification->execute($type, $urlid, $mail);
		$dbh->commit;
		print "Notification type successfully changed.";
	}
	or do
	{
		eval{$dbh->rollback};
		print "Error changing notification type: $@" and die;
	};	
}

sub DeleteNotification
{
	my ($urlid, $mail) = @_;
	IsNumeric($urlid) or print "Invalid URL ID : $urlid" and die;

	eval
	{
		$sth_del_notification->execute($urlid, $mail);
		$dbh->commit;
		print "Notification successfully deleted";
	}
	or do
	{
		eval{$dbh->rollback};
		print "Unable to delete notification: $@" and die;
	};	
}
