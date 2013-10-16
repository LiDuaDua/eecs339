#!/usr/bin/perl -w

#
#
# rwb.pl (Red, White, and Blue)
#
#
# Example code for EECS 339, Northwestern University
#
#
#

# The overall theory of operation of this script is as follows
#
# 1. The inputs are form parameters, if any, and a session cookie, if any.
# 2. The session cookie contains the login credentials (User/Password).
# 3. The parameters depend on the form, but all forms have the following three
#    special parameters:
#
#         act      =  form  <the form in question> (form=base if it doesn't exist)
#         run      =  0 Or 1 <whether to run the form or not> (=0 if it doesn't exist)
#         debug    =  0 Or 1 <whether to provide debugging output or not>
#
# 4. The script then generates relevant html based on act, run, and other
#    parameters that are form-dependent
# 5. The script also sends back a new session cookie (allowing for logout functionality)
# 6. The script also sends back a debug cookie (allowing debug behavior to propagate
#    to child fetches)
#


#
# Debugging
#
# database input and output is paired into the two arrays noted
#
my $debug=1; # default - will be overriden by a form parameter or cookie
my @sqlinput=();
my @sqloutput=();

#
# The combination of -w and use strict enforces various
# rules that make the script more resilient and easier to run
# as a CGI script.
#
use strict;

# The CGI web generation stuff
# This helps make it easy to generate active HTML content
# from Perl
#
# We'll use the "standard" procedural interface to CGI
# instead of the OO default interface
use CGI qw(:standard);


# The interface to the database.  The interface is essentially
# the same no matter what the backend database is.
#
# DBI is the standard database interface for Perl. Other
# examples of such programatic interfaces are ODBC (C/C++) and JDBC (Java).
#
#
# This will also load DBD::Oracle which is the driver for
# Oracle.
use DBI;

#
#
# A module that makes it easy to parse relatively freeform
# date strings into the unix epoch time (seconds since 1970)
#
use Time::ParseDate;


# Using HTML Template because I hate printing HTML
use HTML::Template;
my $template = HTML::Template->new(filename => 'rwb.html');


use Digest::MD5 qw(md5 md5_hex);
#
# You need to override these for access to your database
#
my $dbuser="bsr618";
my $dbpasswd="zf8pO0pRn";


#
# The session cookie will contain the user's name and password so that
# he doesn't have to type it again and again.
#
# "RWBSession"=>"user/password"
#
# BOTH ARE UNENCRYPTED AND THE SCRIPT IS ALLOWED TO BE RUN OVER HTTP
# THIS IS FOR ILLUSTRATION PURPOSES.  IN REALITY YOU WOULD ENCRYPT THE COOKIE
# AND CONSIDER SUPPORTING ONLY HTTPS
#
my $cookiename="RWBSession";
#
# And another cookie to preserve the debug state
#
my $debugcookiename="RWBDebug";

#
# Get the session input and debug cookies, if any
#
my $inputcookiecontent = cookie($cookiename);
my $inputdebugcookiecontent = cookie($debugcookiename);

#
# Will be filled in as we process the cookies and paramters
#
my $outputcookiecontent = undef;
my $outputdebugcookiecontent = undef;
my $deletecookie=0;
my $user = undef;
my $password = undef;
my $logincomplain=0;

#
# Get the user action and whether he just wants the form or wants us to
# run the form
#
my $action;
my $run;


if (defined(param("act"))) {
	$action=param("act");
	if (defined(param("run"))) {
		$run = param("run") == 1;
	} else {
		$run = 0;
	}
} else {
	$action="base";
	$run = 1;
}

my $dstr;

if (defined(param("debug"))) {
	# parameter has priority over cookie
	if (param("debug") == 0) {
		$debug = 0;
	} else {
		$debug = 1;
	}
} else {
	if (defined($inputdebugcookiecontent)) {
		$debug = $inputdebugcookiecontent;
	} else {
		# debug default from script
	}
}

$outputdebugcookiecontent=$debug;

#
#
# Who is this?  Use the cookie or anonymous credentials
#
#
if (defined($inputcookiecontent)) {
	# Has cookie, let's decode it
	($user,$password) = split(/\//,$inputcookiecontent);
	$outputcookiecontent = $inputcookiecontent;
} else {
	# No cookie, treat as anonymous user
	($user,$password) = ("anon","anonanon");
}

#
# Is this a login request or attempt?
# Ignore cookies in this case.
#
if ($action eq "login") {
	if ($run) {
		#
		# Login attempt
		#
		# Ignore any input cookie.  Just validate user and
		# generate the right output cookie, if any.
		#
		($user,$password) = (param('user'),param('password'));
		if (ValidUser($user,$password)) {
			# if the user's info is OK, then give him a cookie
			# that contains his username and password
			# the cookie will expire in one hour, forcing him to log in again
			# after one hour of inactivity.
			# Also, land him in the base query screen
			$outputcookiecontent=join("/",$user,$password);
			$action = "base";
			$run = 1;
		} else {
			# uh oh.  Bogus login attempt.  Make him try again.
			# don't give him a cookie
			$logincomplain=1;
			($user,$password)=("anon","anonanon");
			$action="base";
			$run = 1;
		}
	} else {
		#
		# Just a login screen request, but we should toss out any cookie
		# we were given
		#
		undef $inputcookiecontent;
		($user,$password)=("anon","anonanon");
	}
}


#
# If we are being asked to log out, then if
# we have a cookie, we should delete it.
#
if ($action eq "logout") {
	$deletecookie=1;
	$action = "base";
	$user = "anon";
	$password = "anonanon";
	$run = 1;
}


my @outputcookies;

#
# OK, so now we have user/password
# and we *may* have an output cookie.   If we have a cookie, we'll send it right
# back to the user.
#
# We force the expiration date on the generated page to be immediate so
# that the browsers won't cache it.
#
if (defined($outputcookiecontent)) {
	my $cookie=cookie(-name=>$cookiename,
		-value=>$outputcookiecontent,
		-expires=>($deletecookie ? '-1h' : '+1h'));
	push @outputcookies, $cookie;
}
#
# We also send back a debug cookie
#
#
if (defined($outputdebugcookiecontent)) {
	my $cookie=cookie(-name=>$debugcookiename,
		-value=>$outputdebugcookiecontent);
	push @outputcookies, $cookie;
}

#
# Headers and cookies sent back to client
#
# The page immediately expires so that it will be refetched if the
# client ever needs to update it
#
print header(-expires=>'now', -cookie=>\@outputcookies);

#
# Now we finally begin generating back HTML
#
#
#print start_html('Red, White, and Blue');

if ($action eq "join") {
	my $canjoin = 1;
	my $code;
	my @invite;
	my $email;
	my $referer;

	if(defined(param("code"))){
		$code = param("code");
		eval{ @invite = ExecSQL($dbuser,$dbpasswd,"select email,referer from rwb_invites where code=?","ROW",$code);};

		if(!@invite){
			$canjoin = 0;
		}else{
			($email,$referer) = @invite;
		}
	}else{
		$canjoin = 0;
	}
	if($canjoin){
		if ($run){
			my $error = UserAdd(param("name"),param("password"),param("email"),param("referer"));
			if(!$error){
				eval{ ExecSQL($dbuser,$dbpasswd,"delete from rwb_invites where code=?",undef,$code);};
				print "Success! <a href=\"rwb.pl?act=login&run=1&name=".param("name")."&password=".param("password")."\">Click here to log in.</a>";
			}
		}else{
			print MakeModal("Welcome to RWB! Create your account","join",'<input type="text" class="form-control" name="name" placeholder="Name" required="required" />
				<input type="password" class="form-control" name="password" placeholder="Password" required="required" />
				<input type="text" name="email" style="display:none;" value="'.$email.'" />
				<input type="text" name="referer" style="display:none;" value="'.$referer.'" />
				<input type="text" name="code" style="display:none;" value="'.$code.'" />');

			$action = "base";
		}
	}else{
		print "Error: Something went wrong. Check your activation code.";
	}
}

#
#
# The remainder here is essentially a giant switch statement based
# on $action.
#
#
#
if ($action eq "base") {
	if ($debug) {
		# visible if we are debugging
		$template->param("DEBUG_DISPLAY" => "block");
	} else {
		# invisible otherwise
		$template->param("DEBUG_DISPLAY" => "none");
	}

	my @cycles;
	my $mycycles = "";
	my $cycle;

	eval{ @cycles = ExecSQL($dbuser,$dbpasswd,"SELECT DISTINCT cycle FROM cs339.committee_master UNION SELECT DISTINCT cycle FROM cs339.candidate_master UNION SELECT DISTINCT cycle FROM cs339.individual", "COL"); };

	foreach $cycle(@cycles){
		$mycycles .= "<option>".$cycle."</option>\n";
	}

	$template->param("CYCLES" => $mycycles);

	if ($user eq "anon"){
		$template->param("STATUS" => 'Login');
		$template->param("DROPDOWN" => '<form role="form">
							<div class="col-lg-12">
								<input type="text" class="form-control" name="user" placeholder="Username" />
								<input type="password" name="password" class="form-control" placeholder="Password" required="required" title="">
							</div>
							<input name="act" value="login" style="display: none;">
							<input name="run" value="1" style="display: none;">
							<div class="col-md-12 text-right">
								<button class="btn btn-primary" type="submit">Login</button>
							</div>
						</form>');

		if($logincomplain){
			print '<div id="logincomplain" style="display:none;"></div>'
		}
	} else {
		$template->param("STATUS" => $user);

		my $status_tmp = '';
		if (UserCan($user,"give-opinion-data")) {
			$status_tmp .= '<li><a href="#give-opinion-data" data-toggle="modal">Give Opinion of Current Location</a></li>'."\n";

			$template->param("GIVEOPINION" => MakeModal("Give Opinion of Current Location","give-opinion-data",'
				<div class="row">
					<div class="btn-group col-lg-6 col-lg-offset-3" data-toggle="buttons">
						<label class="btn btn-danger btn-lg">
							<input type="radio" name="color" value="red"> Red
						</label>
						<label class="btn btn-default btn-lg active">
							<input type="radio" name="color" value="white"> White
						</label>
						<label class="btn btn-primary btn-lg">
							<input type="radio" name="color" value="blue"> Blue
						</label>
					</div>
				</div>'));
		}
		if (UserCan($user,"give-cs-ind-data")) {
			$status_tmp .= '<li><a href="#give-cs-ind-data" data-toggle="modal">Geolocate Individual Contributors</a></li>'."\n";
		}
		if (UserCan($user,"manage-users") || UserCan($user,"invite-users")) {
			$status_tmp .= '<li><a href="#invite-user" data-toggle="modal">Invite User</a></li>'."\n";

			$template->param("INVITE-USER" => MakeModal("Invite User","invite-user",'<input type="email" class="form-control" name="email" placeholder="Email" required="required" />'));
		}
		if (UserCan($user,"manage-users") || UserCan($user,"add-users")) {
			$status_tmp .= '<li><a href="#add-user" data-toggle="modal">Add User</a></li>'."\n";

			$template->param("ADD-USER" => MakeModal("Add User","add-user",'<input type="text" class="form-control" name="name" placeholder="Name" required="required" />
								<input type="text" class="form-control" name="email" placeholder="Email" required="required" />
								<input type="password" class="form-control" name="password" placeholder="Password" required="required" />'));
		}
		if (UserCan($user,"manage-users")) {
			$status_tmp .= '<li><a href="#delete-user" data-toggle="modal">Delete User</a></li>'."\n";
			$status_tmp .= '<li><a href="#add-perm-user" data-toggle="modal">Add User Permission</a></li>'."\n";
			$status_tmp .= '<li><a href="#revoke-perm-user" data-toggle="modal">Revoke User Permission</a></li>'."\n";

			my $out = MakeModal("Delete User","delete-user",'<input type="text" class="form-control" name="name" placeholder="Name" required="required" />');

			$template->param("DELETE-USER" => $out);

			my $inputs = '<input type="text" class="form-control" name="name" placeholder="Name" />
						<input type="text" class="form-control" name="permission" placeholder="Permission" />';
			my ($table,$error);
			($table,$error)=PermTable();
			if (!$error) {
				$inputs .= "<h5>Available Permissions</h5>$table";
			}

			$out = MakeModal("Add User Permission","add-perm-user",$inputs);

			$template->param("ADD-PERM-USER" => $out);

			$out = MakeModal("Revoke User Permission","revoke-perm-user",$inputs);

			$template->param("REVOKE-PERM-USER" => $out);
		}
		$status_tmp .= '<li><a href="rwb.pl?act=logout&run=1">Logout</a></li>';

		$template->param("DROPDOWN" => $status_tmp);
	}

	print "<!DOCTYPE HTML>", $template->output;
}

sub MakeModal {
	my ($title,$act,$inputs) = @_;

	return '<div id="'.$act.'" class="modal fade">
			<div class="modal-dialog">
				<div class="modal-content">
					<div class="modal-header">
						<button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>
						<h4 class="modal-title">'.$title.'</h4>
					</div>
					<div class="modal-body">
						<form role="form" onsubmit="$(\'.modal\').modal(\'hide\'); return false;">
							<div class="col-lg-12">
								'.$inputs.'
							</div>
							<input type="text" name="run" value="1" style="display: none;" />
							<input type="text" name="act" value="'.$act.'" style="display: none;" />
							<div class="col-md-12 text-right">
								<button class="btn btn-primary" type="submit">Submit</button>
							</div>
						</form>
					</div>
				</div><!-- /.modal-content -->
			</div><!-- /.modal-dialog -->
		</div><!-- /.modal -->';
}

#
# NEAR
#
# Nearby committees, candidates, individuals, and opinions
#
#
# Note that the individual data should integrate the FEC data and the more
# precise crowd-sourced location data.   The opinion data is completely crowd-sourced
#
# This form intentionally avoids decoration since the expectation is that
# the client-side javascript will invoke it to get raw data for overlaying on the map
#
#
if ($action eq "near") {
	my $latne = param("latne");
	my $longne = param("longne");
	my $latsw = param("latsw");
	my $longsw = param("longsw");
	my $whatparam = param("what");
	my $format = param("format");
	my $cycle = param("cycle");
	my %what;

	$format = "table" if !defined($format);
	$cycle = "'1112'" if !defined($cycle);

	if (!defined($whatparam) || $whatparam eq "all") {
		%what = ( committees => 1,
			candidates => 1,
			individuals =>1,
			opinions => 1);
	} else {
		map {$what{$_}=1} split(/\s*,\s*/,$whatparam);
	}


	if ($what{committees}) {
		# my ($str,$error) = Committees($latne,$longne,$latsw,$longsw,$cycle,$format);
		# if (!$error) {
		# 	if ($format eq "table") {
		# 		print "<h2>Nearby committees</h2>$str";
		# 	} else {
		# 		print $str;
		# 	}
		# }

		my ($sum,$error2) = CommitteesAggregate($latne,$longne,$latsw,$longsw,$cycle,$format,"'Rep','REP','rep'");
		if (!$error2) {
			if ($format eq "table") {
				print "<h2>Committees Aggregate</h2>$sum";
			} else {
				print $sum;
			}
		}
	}
	if ($what{candidates}) {
		my ($str,$error) = Candidates($latne,$longne,$latsw,$longsw,$cycle,$format);
		if (!$error) {
			if ($format eq "table") {
				print "<h2>Nearby candidates</h2>$str";
			} else {
				print $str;
			}
		}
	}
	if ($what{individuals}) {
		my ($str,$error) = Individuals($latne,$longne,$latsw,$longsw,$cycle,$format);
		if (!$error) {
			if ($format eq "table") {
				print "<h2>Nearby individuals</h2>$str";
			} else {
				print $str;
			}
		}
	}
	if ($what{opinions} && UserCan($user,"query-opinion-data")) {
		my ($str,$error) = Opinions($latne,$longne,$latsw,$longsw,$cycle,$format);
		if (!$error) {
			if ($format eq "table") {
				print "<h2>Nearby opinions</h2>$str";
			} else {
				print $str;
			}
		}
	}
}


if ($action eq "invite-user") {
	if (!UserCan($user,"invite-users")) {
		print "You do not have the required permissions to invite users.";
	} else {
		if ($run){
			my $email=param('email');
			my $code = md5_hex($email);
			my $error = UserInvite($code,$email,$user);
			if ($error) {
				print "Can't invite user because: $error";
			} else {
				print "Invitation sent!";
			}
		}
	}
}

if ($action eq "give-opinion-data") {
	if (!UserCan($user,"give-opinion-data")) {
		print "You do not have the required permissions to give opinion data.";
	} else {
		if($run){
			my $color = param('color');

			if($color == "red"){
				$color = -1;
			} elsif($color == "blue"){
				$color = 1;
			}else{
				$color = 0;
			}

			my $error = UserOpinion($user,$color,param('lat'),param('lng'));
			if ($error) {
				print "Can't submit opinion because: $error";
			} else {
				print "Opinion submitted!";
			}
		}
	}
}

if ($action eq "give-cs-ind-data") {
	print h2("Giving Crowd-sourced Individual Geolocations Is Unimplemented");
}

#
# ADD-USER
#
# User Add functionaltiy
if ($action eq "add-user") {
	if (!UserCan($user,"add-users") && !UserCan($user,"manage-users")) {
		print 'You do not have the required permissions to add users.';
	} else {
		if ($run) {
			my $name=param('name');
			my $email=param('email');
			my $password=param('password');
			my $error;
			$error=UserAdd($name,$password,$email,$user);
			if ($error) {
				print "Can't add user because: $error";
			} else {
				print "Added user $name $email as referred by $user\n";
			}
		}
	}
}

#
# DELETE-USER
#
# User Delete functionaltiy
if ($action eq "delete-user") {
	if (!UserCan($user,"manage-users")) {
		print 'You do not have the required permissions to delete users.';
	} else {
		if ($run) {
			my $name=param('name');
			my $error;
			$error=UserDelete($name);
			if ($error) {
				print "Can't delete user because: $error";
			} else {
				print "Deleted user $name\n";
			}
		}
	}
}


#
# ADD-PERM-USER
#
# User Add Permission functionaltiy
if ($action eq "add-perm-user") {
	if (!UserCan($user,"manage-users")) {
		print 'You do not have the required permissions to manage user permissions.';
	} else {
		if ($run) {
			my $name=param('name');
			my $perm=param('permission');
			my $error=GiveUserPerm($name,$perm);
			if ($error) {
				print "Can't add permission to user because: $error";
			} else {
				print "Gave user $name permission $perm\n";
			}
		}
	}
}


#
# REVOKE-PERM-USER
#
# User Permission Revocation functionaltiy
if ($action eq "revoke-perm-user") {
	if (!UserCan($user,"manage-users")) {
		print 'You do not have the required permissions to manage user permissions.';
	} else {
		if ($run) {
			my $name=param('name');
			my $perm=param('permission');
			my $error=RevokeUserPerm($name,$perm);
			if ($error) {
				print "Can't revoke permission from user because: $error";
			} else {
				print "Revoked user $name permission $perm\n";
			}
		}
	}
}


#
# Generate debugging output if anything is enabled.
if ($debug) {
	print hr, p, hr,p, h2('Debugging Output');
	print h3('Parameters');
	print "<menu>";
	print map { "<li>$_ => ".escapeHTML(param($_)) } param();
	print "</menu>";
	print h3('Cookies');
	print "<menu>";
	print map { "<li>$_ => ".escapeHTML(cookie($_))} cookie();
	print "</menu>";
	my $max= $#sqlinput>$#sqloutput ? $#sqlinput : $#sqloutput;
	print h3('SQL');
	print "<menu>";
	for (my $i=0;$i<=$max;$i++) {
		print "<li><b>Input:</b> ".escapeHTML($sqlinput[$i]);
		print "<li><b>Output:</b> $sqloutput[$i]";
	}
	print "</menu>";
}


#
# Generate a table of nearby committees
# ($table|$raw,$error) = Committees(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Committees {
	my ($latne,$longne,$latsw,$longsw,$cycle,$format) = @_;
	my @rows;
	my $statement = "select latitude, longitude, cmte_nm, cmte_pty_affiliation, cmte_st1, cmte_st2, cmte_city, cmte_st, cmte_zip from cs339.committee_master natural join cs339.cmte_id_to_geo where cycle in (".$cycle.") and latitude>? and latitude<? and longitude>? and longitude<?";
	eval {
		@rows = ExecSQL($dbuser, $dbpasswd, $statement,undef,$latsw,$latne,$longsw,$longne);
	};

	if ($@) {
		return (undef,$@);
	} else {
		if ($format eq "table") {
			return (MakeTable("committee_data","2D",
				["latitude", "longitude", "name", "party", "street1", "street2", "city", "state", "zip"],
				@rows),$@);
		} elsif ($format eq "json") {
			return encode_json(@rows);
		} else {
			return (MakeRaw("committee_data","2D",@rows),$@);
		}
	}
}

sub CommitteesAggregate {
	my ($latne,$longne,$latsw,$longsw,$cycle,$format,$party) = @_;
	my $sum;
	my $statement = "SELECT SUM(transaction_amnt) from(
					SELECT DISTINCT cs339.comm_to_cand.transaction_amnt,cs339.comm_to_cand.cmte_id,cs339.comm_to_cand.cycle,cs339.comm_to_cand.tran_id
						FROM cs339.comm_to_cand
							INNER JOIN cs339.cmte_id_to_geo ON cs339.comm_to_cand.cmte_id=cs339.cmte_id_to_geo.cmte_id
							INNER JOIN cs339.candidate_master cm ON cs339.comm_to_cand.cand_id=cm.cand_id
							INNER JOIN cs339.candidate_master cm2 ON cs339.comm_to_cand.cycle=cm2.cycle
							WHERE latitude>? and latitude<? and longitude>? and longitude<? and cs339.comm_to_cand.cycle in (".$cycle.") and cm.cand_pty_affiliation IN (".$party.")
					UNION
					SELECT DISTINCT cs339.comm_to_comm.transaction_amnt,cs339.comm_to_comm.cmte_id,cs339.comm_to_comm.cycle,cs339.comm_to_comm.tran_id
						FROM cs339.comm_to_comm
							INNER JOIN cs339.cmte_id_to_geo ON cs339.comm_to_comm.cmte_id=cs339.cmte_id_to_geo.cmte_id
							INNER JOIN cs339.committee_master cm3 ON cs339.comm_to_comm.cmte_id=cm3.cmte_id
							INNER JOIN cs339.committee_master cm4 ON cs339.comm_to_comm.cycle=cm4.cycle
							WHERE latitude>? and latitude<? and longitude>? and longitude<? and cs339.comm_to_comm.cycle in (".$cycle.") and cm3.cmte_pty_affiliation IN (".$party."))";

	# my $statement = "SELECT SUM(transaction_amnt) from( SELECT DISTINCT cs339.comm_to_cand.transaction_amnt,cs339.comm_to_cand.cmte_id,cs339.comm_to_cand.cycle,cs339.comm_to_cand.tran_id 	FROM cs339.comm_to_cand INNER JOIN cs339.cmte_id_to_geo ON cs339.comm_to_cand.cmte_id=cs339.cmte_id_to_geo.cmte_id INNER JOIN cs339.candidate_master cm ON cs339.comm_to_cand.cand_id=cm.cand_id INNER JOIN cs339.candidate_master cm2 ON cs339.comm_to_cand.cycle=cm2.cycle WHERE latitude>42 and latitude<42.1 and longitude>-87.85 and longitude<-87.41 and cm.cand_pty_affiliation IN ('Rep','REP','rep') UNION SELECT DISTINCT cs339.comm_to_comm.transaction_amnt,cs339.comm_to_comm.cmte_id,cs339.comm_to_comm.cycle,cs339.comm_to_comm.tran_id FROM cs339.comm_to_comm INNER JOIN cs339.cmte_id_to_geo ON cs339.comm_to_comm.cmte_id=cs339.cmte_id_to_geo.cmte_id INNER JOIN cs339.committee_master cm ON cs339.comm_to_comm.cmte_id=cm.cmte_id INNER JOIN cs339.committee_master cm2 ON cs339.comm_to_comm.cycle=cm2.cycle WHERE latitude>42 and latitude<42.1 and longitude>-87.85 and longitude<-87.41 and cm.cmte_pty_affiliation IN ('Rep','REP','rep'))";
	eval {
		$sum = ExecSQL($dbuser,$dbpasswd,$statement,undef,$latsw,$latne,$longsw,$longne,$latsw,$latne,$longsw,$longne);
	};

	if ($@) {
		return (undef,$@);
	} else {
		return ($sum,$@);#return (MakeTable("committee_aggregate_data","2D",["sum"],@sum),$@);
	}
}


#
# Generate a table of nearby candidates
# ($table|$raw,$error) = Committees(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Candidates {
	my ($latne,$longne,$latsw,$longsw,$cycle,$format) = @_;
	my @rows;
	my $statement = "select latitude, longitude, cand_name, cand_pty_affiliation, cand_st1, cand_st2, cand_city, cand_st, cand_zip from cs339.candidate_master natural join cs339.cand_id_to_geo where cycle in (".$cycle.") and latitude>? and latitude<? and longitude>? and longitude<?";
	eval {
		@rows = ExecSQL($dbuser, $dbpasswd, $statement,undef,$latsw,$latne,$longsw,$longne);
	};

	if ($@) {
		return (undef,$@);
	} else {
		if ($format eq "table") {
			return (MakeTable("candidate_data", "2D",
				["latitude", "longitude", "name", "party", "street1", "street2", "city", "state", "zip"],
				@rows),$@);
		} elsif ($format eq "json") {
			return encode_json(@rows);
		} else {
			return (MakeRaw("candidate_data","2D",@rows),$@);
		}
	}
}


#
# Generate a table of nearby individuals
#
# Note that the handout version does not integrate the crowd-sourced data
#
# ($table|$raw,$error) = Individuals(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Individuals {
	my ($latne,$longne,$latsw,$longsw,$cycle,$format) = @_;
	my @rows;
	my $statement = "select latitude, longitude, name, city, state, zip_code, employer, transaction_amnt from cs339.individual natural join cs339.ind_to_geo where cycle in (".$cycle.") and latitude>? and latitude<? and longitude>? and longitude<?";
	eval {
		@rows = ExecSQL($dbuser, $dbpasswd, $statement,undef,$latsw,$latne,$longsw,$longne);
	};

	if ($@) {
		return (undef,$@);
	} else {
		if ($format eq "table") {
			return (MakeTable("individual_data", "2D",
				["latitude", "longitude", "name", "city", "state", "zip", "employer", "amount"],
				@rows),$@);
		} elsif ($format eq "json") {
			return encode_json(@rows);
		} else {
			return (MakeRaw("individual_data","2D",@rows),$@);
		}
	}
}


#
# Generate a table of nearby opinions
#
# ($table|$raw,$error) = Opinions(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Opinions {
	my ($latne, $longne, $latsw, $longsw, $cycle,$format) = @_;
	my @rows;
	eval {
		@rows = ExecSQL($dbuser, $dbpasswd, "select latitude, longitude, color from rwb_opinions where latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne);
	};

	if ($@) {
		return (undef,$@);
	} else {
		if ($format eq "table") {
			return (MakeTable("opinion_data","2D",
				["latitude", "longitude", "name", "city", "state", "zip", "employer", "amount"],
				@rows),$@);
		} elsif ($format eq "json") {
			return encode_json(@rows);
		} else {
			return (MakeRaw("opinion_data","2D",@rows),$@);
		}
	}
}


#
# Generate a table of available permissions
# ($table,$error) = PermTable()
# $error false on success, error string on failure
#
sub PermTable {
	my @rows;
	eval { @rows = ExecSQL($dbuser, $dbpasswd, "select action from rwb_actions"); };
	if ($@) {
		return (undef,$@);
	} else {
		return (MakeTable("perm_table",
			"2D",
			["Perm"],
			@rows),$@);
	}
}

#
# Generate a table of users
# ($table,$error) = UserTable()
# $error false on success, error string on failure
#
sub UserTable {
	my @rows;
	eval { @rows = ExecSQL($dbuser, $dbpasswd, "select name, email from rwb_users order by name"); };
	if ($@) {
		return (undef,$@);
	} else {
		return (MakeTable("user_table",
			"2D",
			["Name", "Email"],
			@rows),$@);
	}
}

#
# Generate a table of users and their permissions
# ($table,$error) = UserPermTable()
# $error false on success, error string on failure
#
sub UserPermTable {
	my @rows;
	eval { @rows = ExecSQL($dbuser, $dbpasswd, "select rwb_users.name, rwb_permissions.action from rwb_users, rwb_permissions where rwb_users.name=rwb_permissions.name order by rwb_users.name"); };
	if ($@) {
		return (undef,$@);
	} else {
		return (MakeTable("userperm_table",
			"2D",
			["Name", "Permission"],
			@rows),$@);
	}
}

sub UserInvite {
	eval { ExecSQL($dbuser,$dbpasswd,"insert into rwb_invites (code,email,referer) values (?,?,?)",undef,@_);};
	my ($code,$email,$referer) = @_;

	if(!$@){
		open(MAIL,"| mail -s 'Invitation to RWB!' $email") or die "Can't run mail\n";
		print MAIL "Click here for your exclusive invitation to RWB: http://murphy.wot.eecs.northwestern.edu/~bsr618/rwb/rwb.pl?act=join&code=$code\n";
		close(MAIL);
	}

	return $@;
}

sub UserOpinion {
	eval { ExecSQL($dbuser,$dbpasswd,"insert into rwb_opinions (submitter,color,latitude,longitude) values (?,?,?,?)",undef,@_);};
	return $@;
}

#
# Add a user
# call with name,password,email
#
# returns false on success, error string on failure.
#
# UserAdd($name,$password,$email)
#
sub UserAdd {
	eval { ExecSQL($dbuser,$dbpasswd,
		"insert into rwb_users (name,password,email,referer) values (?,?,?,?)",undef,@_);};
	my ($usr,$a,$b,$c) = @_;
	GiveUserPerm($usr,"invite-users");
	GiveUserPerm($usr,"query-fec-data");
	GiveUserPerm($usr,"query-opinion-data");
	GiveUserPerm($usr,"give-opinion-data");
	return $@;
}

#
# Delete a user
# returns false on success, $error string on failure
#
sub UserDel {
	eval {ExecSQL($dbuser,$dbpasswd,"delete from rwb_users where name=?", undef, @_);};
	return $@;
}


#
# Give a user a permission
#
# returns false on success, error string on failure.
#
# GiveUserPerm($name,$perm)
#
sub GiveUserPerm {
	eval { ExecSQL($dbuser,$dbpasswd,
		"insert into rwb_permissions (name,action) values (?,?)",undef,@_);};
	return $@;
}

#
# Revoke a user's permission
#
# returns false on success, error string on failure.
#
# RevokeUserPerm($name,$perm)
#
sub RevokeUserPerm {
	eval { ExecSQL($dbuser,$dbpasswd,
		"delete from rwb_permissions where name=? and action=?",undef,@_);};
	return $@;
}

#
#
# Check to see if user and password combination exist
#
# $ok = ValidUser($user,$password)
#
#
sub ValidUser {
	my ($user,$password)=@_;
	my @col;
	eval {@col=ExecSQL($dbuser,$dbpasswd, "select count(*) from rwb_users where name=? and password=?","COL",$user,$password);};
	if ($@) {
		return 0;
	} else {
		return $col[0]>0;
	}
}

#
# Check to see if user can do some action
#
# $ok = UserCan($user,$action)
#
sub UserCan {
	my ($user,$action)=@_;
	my @col;
	eval {@col= ExecSQL($dbuser,$dbpasswd, "select count(*) from rwb_permissions where name=? and action=?","COL",$user,$action);};
	if ($@) {
		return 0;
	} else {
		return $col[0]>0;
	}
}

#
# Given a list of scalars, or a list of references to lists, generates
# an html table
#
#
# $type = undef || 2D => @list is list of references to row lists
# $type = ROW   => @list is a row
# $type = COL   => @list is a column
#
# $headerlistref points to a list of header columns
#
#
# $html = MakeTable($id, $type, $headerlistref,@list);
#
sub MakeTable {
	my ($id,$type,$headerlistref,@list)=@_;
	my $out;
	#
	# Check to see if there is anything to output
	#
	if ((defined $headerlistref) || ($#list>=0)) {
		# if there is, begin a table
		#
		$out="<table id=\"$id\" class=\"table table-bordered table-striped\">";
		#
		# if there is a header list, then output it in bold
		#
		if (defined $headerlistref) {
			$out.="<tr>".join("",(map {"<th>$_</th>"} @{$headerlistref}))."</tr>";
		}
		#
		# If it's a single row, just output it in an obvious way
		#
		if ($type eq "ROW") {
			#
			# map {code} @list means "apply this code to every member of the list
			# and return the modified list.  $_ is the current list member
			#
			$out.="<tr>".(map {defined($_) ? "<td>$_</td>" : "<td>(null)</td>" } @list)."</tr>";
		} elsif ($type eq "COL") {
			#
			# ditto for a single column
			#
			$out.=join("",map {defined($_) ? "<tr><td>$_</td></tr>" : "<tr><td>(null)</td></tr>"} @list);
		} else {
			#
			# For a 2D table, it's a bit more complicated...
			#
			$out.= join("",map {"<tr>$_</tr>"} (map {join("",map {defined($_) ? "<td>$_</td>" : "<td>(null)</td>"} @{$_})} @list));
		}
		$out.="</table>";
	} else {
		# if no header row or list, then just say none.
		$out.="(none)";
	}
	return $out;
}

#
# Given a list of scalars, or a list of references to lists, generates
# an HTML <pre> section, one line per row, columns are tab-deliminted
#
#
# $type = undef || 2D => @list is list of references to row lists
# $type = ROW   => @list is a row
# $type = COL   => @list is a column
#
#
# $html = MakeRaw($id, $type, @list);
#
sub MakeRaw {
	my ($id, $type,@list)=@_;
	my $out;
	#
	# Check to see if there is anything to output
	#
	$out="<pre id=\"$id\">\n";
	#
	# If it's a single row, just output it in an obvious way
	#
	if ($type eq "ROW") {
		#
		# map {code} @list means "apply this code to every member of the list
		# and return the modified list.  $_ is the current list member
		#
		$out.=join("\t",map { defined($_) ? $_ : "(null)" } @list);
		$out.="\n";
		} elsif ($type eq "COL") {
		#
		# ditto for a single column
		#
		$out.=join("\n",map { defined($_) ? $_ : "(null)" } @list);
		$out.="\n";
		} else {
		#
		# For a 2D table
		#
		foreach my $r (@list) {
			$out.= join("\t", map { defined($_) ? $_ : "(null)" } @{$r});
			$out.="\n";
		}
	}
	$out.="</pre>\n";
	return $out;
}

#
# @list=ExecSQL($user, $password, $querystring, $type, @fill);
#
# Executes a SQL statement.  If $type is "ROW", returns first row in list
# if $type is "COL" returns first column.  Otherwise, returns
# the whole result table as a list of references to row lists.
# @fill are the fillers for positional parameters in $querystring
#
# ExecSQL executes "die" on failure.
#
sub ExecSQL {
	my ($user, $passwd, $querystring, $type, @fill) =@_;
	if ($debug) {
		# if we are recording inputs, just push the query string and fill list onto the
		# global sqlinput list
		push @sqlinput, "$querystring (".join(",",map {"'$_'"} @fill).")";
	}
	my $dbh = DBI->connect("DBI:Oracle:",$user,$passwd);
	if (not $dbh) {
		# if the connect failed, record the reason to the sqloutput list (if set)
		# and then die.
		if ($debug) {
			push @sqloutput, "<b>ERROR: Can't connect to the database because of ".$DBI::errstr."</b>";
		}
		die "Can't connect to database because of ".$DBI::errstr;
	}
	my $sth = $dbh->prepare($querystring);
	if (not $sth) {
		#
		# If prepare failed, then record reason to sqloutput and then die
		#
		if ($debug) {
			push @sqloutput, "<b>ERROR: Can't prepare '$querystring' because of ".$DBI::errstr."</b>";
		}
		my $errstr="Can't prepare $querystring because of ".$DBI::errstr;
		$dbh->disconnect();
		die $errstr;
	}
	if (not $sth->execute(@fill)) {
		#
		# if exec failed, record to sqlout and die.
		if ($debug) {
			push @sqloutput, "<b>ERROR: Can't execute '$querystring' with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr."</b>";
		}
		my $errstr="Can't execute $querystring with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr;
		$dbh->disconnect();
		die $errstr;
	}
	#
	# The rest assumes that the data will be forthcoming.
	#
	#
	my @data;
	if (defined $type and $type eq "ROW") {
		@data=$sth->fetchrow_array();
		$sth->finish();
		if ($debug) {push @sqloutput, MakeTable("debug_sqloutput","ROW",undef,@data);}
		$dbh->disconnect();
		return @data;
	}
	my @ret;
	while (@data=$sth->fetchrow_array()) {
		push @ret, [@data];
	}
	if (defined $type and $type eq "COL") {
		@data = map {$_->[0]} @ret;
		$sth->finish();
		if ($debug) {push @sqloutput, MakeTable("debug_sqloutput","COL",undef,@data);}
		$dbh->disconnect();
		return @data;
	}
	$sth->finish();
	if ($debug) {push @sqloutput, MakeTable("debug_sql_output","2D",undef,@ret);}
	$dbh->disconnect();
	return @ret;
}

# The following is necessary so that DBD::Oracle can find its butt
#
BEGIN {
	unless ($ENV{BEGIN_BLOCK}) {
		use Cwd;
		$ENV{ORACLE_BASE}="/raid/oracle11g/app/oracle/product/11.2.0.1.0";
		$ENV{ORACLE_HOME}=$ENV{ORACLE_BASE}."/db_1";
		$ENV{ORACLE_SID}="CS339";
		$ENV{LD_LIBRARY_PATH}=$ENV{ORACLE_HOME}."/lib";
		$ENV{BEGIN_BLOCK} = 1;
		exec 'env',cwd().'/'.$0,@ARGV;
	}
}

