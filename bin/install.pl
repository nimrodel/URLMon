#!/usr/bin/perl
use DBI;
use DBD::Mysql;
my $db;
my $user;
my $pass;

open( CONF, <> );

while (<CONF>)
{
	chomp;
	my @row = split( '=', $_ );
	
	$db = $row[1] if $row[0] eq "dbname";
	$user = $row[1] if $row[0] eq "user";
	$pass = $row[1] if $row[0] eq "pass";
}

$qpass = "'$pass'";
close(CONF);

#Create user
$res = `mysql -u root -e "CREATE USER $user IDENTIFIED BY $qpass;"
		mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO $user@localhost";`;

#Create DB
my $drh = DBI->install_driver("mysql");
die unless $rc = $drh->func("createdb", $db, "localhost", $user, $pass, 'admin');

#Connect to DB
my $dsn = "DBI:mysql:$db:localhost:3306";
my $dbh = DBI->connect( $dsn, 
						$user, 
						$pass,
						{ RaiseError => 1,
						  AutoCommit => 0} ) or die $DBI::errstr;
#Create tables
eval
{
	$dbh->do( "CREATE TABLE urls
					( id INT PRIMARY KEY AUTO_INCREMENT,
					  url VARCHAR(200) NOT NULL,
					  int_sec BIGINT NOT NULL,
					  l_checked DATETIME
					);" ) or die "Unable to create table 'urls': $DBI::errstr";

	$dbh->do( "CREATE TABLE groups
					( name VARCHAR(50) NOT NULL,
					  url_id INT NOT NULL
					);" ) or die "Unable to create table 'groups': $DBI::errstr";
									
	# on_event: 1 - up; 2 - down; 3 - both													
	$dbh->do( "CREATE TABLE notifications
					( url_id INT NOT NULL,
					  mail VARCHAR(100) NOT NULL,
					  type INT NOT NULL,
					  CHECK( type IN (0, 1, 2)),
					  CONSTRAINT uq_entry UNIQUE(url_id, mail, type) 
					);" ) or die "Unable to create table 'notifications': $DBI::errstr";
					
	$dbh->do( "CREATE TABLE logs
					( dt DATETIME NOT NULL,
					  url_id INT NOT NULL,
					  status INT NOT NULL,
					  CHECK( status in (0, 1))
					  );" ) or die "Unable to create table 'logs': $DBI::errstr";
	$dbh->commit;
	1;				
}
or do
{
	$dbh->rollback;
	die "Error creating tables: $@";
}
