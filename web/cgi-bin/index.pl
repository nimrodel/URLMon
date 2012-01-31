#!/usr/bin/perl
use strict;
use DBI;
use CGI;

our %cached_queries;

sub DBconnect
{
	my $database = "urlmon";
	my $dsn = "dbi:mysql:$database:localhost:3306";
	my $dbh = DBI->connect( $dsn,
							"root",                          # user
							"",                          # password
							{ RaiseError => 1 },         # complain if something goes wrong
							) or die $DBI::errstr; 
}

sub CacheQueries
{
	my $dbh = $_[0];
	
	$main::cached_queries{'add_url'} = $dbh->prepare( "INSERT INTO urls (url, int_sec) VALUES(?, ?);");
	$main::cached_queries{'add_url_to_group'} = $dbh->prepare( "INSERT INTO groups VALUES( ?, ? );");
	$main::cached_queries{'check_url_exists'} = $dbh->prepare("SELECT COUNT(*) FROM urls WHERE url = ?;"); 
	$main::cached_queries{'check_url_in_group'} = $dbh->prepare("SELECT COUNT(*) FROM groups WHERE url_id = ? AND name = ?;");
	
	$main::cached_queries{'get_urls'} = $dbh->prepare("SELECT * FROM urls");
	$main::cached_queries{'get_url_by_id'} = $dbh->prepare("SELECT * FROM urls WHERE url_id = ?");
	
	$main::cached_queries{'get_groups_by_urlid'} = $dbh->prepare("SELECT DISTINCT name FROM groups WHERE url_id = ?");
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

sub ShowHeader;
sub ShowMenu;
sub ShowUrls;
sub ShowGroups;
sub ShowFooter;


my $cgi = CGI->new;
my $dbh = DBconnect();
CacheQueries($dbh);

my $mode = "urls";
my $id = undef;
my $func = undef;
my $args = undef;


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
	print $cgi->header();
	
	#print $func.' '.$args.'\n';
	
	my @args = split(/\|/, $args);
	
	if($func eq "add_group")
	{
		if(!IsNumeric($args[0]))
		{
			print "Invalid URL ID : $args[0]";
		}
		
		print ">1>";
		
		$main::cached_queries{'get_url_by_id'}->execute($args[0]);
		
		print ">2>";
		
		my $row = $main::cached_queries{'get_url_by_id'}->fetchrow_array();
		
		
		print ">2>";
		
		if($row)
		{
			print "URL ID does not exist: $args[0]";
		}
		
	}
}


sub ShowHeader
{
	print $cgi->header(-encoding => "utf8", -charset=>"utf8");
	print $cgi->start_html(
		-title=>'URLmon',
		-style=>{'src'=>'/css/style.css'},
		-script=>{-type=>'javascript', -src=>'/js/urlmon.js'}
		);
	#print "mode:$mode </br> id:$id def:".defined($id).'</br>';
}

sub ShowFooter
{
	print $cgi->end_html();
}

sub ShowMenu($)
{
	my $mode = shift;
	print "\t".$cgi->div(
		{-class=>"menu"},
		"\n\t\t".
		$cgi->a({-href=>'?urls=',   -class=> ($mode eq "urls" ? 'selected' : "")}, "URLs").
		$cgi->a({-href=>'?groups=', -class=> ($mode eq "groups" ? 'selected' : "")}, "Groups").
		"\t\n\t"
	)."\n";
}

sub ShowUrls
{
	my $tmp = "";
	
	$main::cached_queries{'get_urls'}->execute();
	
	print "\t".$cgi->start_table({-class=>'list'})."\n";
		
	print "\t".$cgi->start_Tr({-class=>"header"})."\n";
	print "\t\t<td width=\"40\" align=\"center\">ID</td>\n";
	print "\t\t<td>Address</td>\n";
	print "\t\t<td width=\"100\">Interval</td>\n";
	print "\t\t<td width=\"200\">Status</td>\n";
	print "\t".$cgi->end_Tr()."\n";
	
	while( my @row = $main::cached_queries{'get_urls'}->fetchrow_array() )
	{
		#(my $id, my $url, my $interval, my $last_checked ) = @row;
		print "\t".$cgi->start_Tr({-class=>"mainline"})."\n";
		print "\t\t<td align=\"center\">$row[0]</td>\n";
		print "\t\t<td>$row[1]</td>\n";
		print "\t\t<td>$row[2]</td>\n";
		print "\t\t<td>$row[3]</td>\n";
		print "\t".$cgi->end_Tr()."\n";
		
		print "\t".$cgi->start_Tr({-class=>"detailline"})."\n";
		print "\t\t<td colspan=\"4\">\n";
		print "\t\t\t".
			$cgi->a({
				-href=>"javascript: ToggleByID('group$row[0]')",
				-class=>"group"},
				$cgi->img({
					-id=>"group$row[0]image",
					-src=>"../images/plus.png",
					-alt=>""})." Groups"
			)."\n";
		
		
		$main::cached_queries{'get_groups_by_urlid'}->execute($row[0]);
		print "\t\t\t".$cgi->start_div({-id=>"group$row[0]", -class=>"group invisible"})."\n";
		print "\t\t\t\t".$cgi->start_table({-class=>"grouplist"})."\n";
		while( my @groups = $main::cached_queries{'get_groups_by_urlid'}->fetchrow_array() )
		{
			print "\t\t\t\t".
					$cgi->Tr(
						"\n\t\t\t\t\t<td>".$cgi->a({-href=>"')"}, $groups[0])."</td>".
						"\n\t\t\t\t\t<td>".$cgi->button(
							{
								-class=>"button",
								value=>"Remove"
							})."</td>\n\t\t\t\t"
					)."\n";
		}
		print "\t\t\t\t".
				$cgi->Tr(
					"\n\t\t\t\t\t<td width=\"100%\">".$cgi->input(
						{
							-id=>"new_group_$row[0]",
							-type=>"text"
						})."</td>".
					"\n\t\t\t\t\t<td>".$cgi->button(
						{
							-class=>"button",
							-value=>"Add",
							-onClick=>"javascript: AddGroup('$row[0]')"
						})."</td>\n\t\t\t\t"
				)."\n";
		print "\t\t\t\t".$cgi->end_table()."\n";
		print "\t\t\t".$cgi->end_div()."\n";
		
		print "\t\t</td>\n";
		print "\t".$cgi->end_Tr()."\n";
	}
	
	print "\t".$cgi->end_table()."\n";
}

sub ShowGroups
{
	
}

