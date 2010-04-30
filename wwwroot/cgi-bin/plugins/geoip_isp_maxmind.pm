#!/usr/bin/perl
#-----------------------------------------------------------------------------
# GeoIp_Isp_Maxmind AWStats plugin
# This plugin allow you to add a city report.
# Need the licensed ISP database from Maxmind.
#-----------------------------------------------------------------------------
# Perl Required Modules: Geo::IP or Geo::IP::PurePerl
#-----------------------------------------------------------------------------
# $Revision: 1.15 $ - $Author: manolamancha $ - $Date: 2010-04-30 12:36:09 $


# <-----
# ENTER HERE THE USE COMMAND FOR ALL REQUIRED PERL MODULES
use vars qw/ $type /;
$type='geoip';
if (!eval ('require "Geo/IP.pm";')) {
	$error1=$@;
	$type='geoippureperl';
	if (!eval ('require "Geo/IP/PurePerl.pm";')) {
		$error2=$@;
		$ret=($error1||$error2)?"Error:\n$error1$error2":"";
		$ret.="Error: Need Perl module Geo::IP or Geo::IP::PurePerl";
		return $ret;
	}
}
# ----->
#use strict;
no strict "refs";



#-----------------------------------------------------------------------------
# PLUGIN VARIABLES
#-----------------------------------------------------------------------------
# <-----
# ENTER HERE THE MINIMUM AWSTATS VERSION REQUIRED BY YOUR PLUGIN
# AND THE NAME OF ALL FUNCTIONS THE PLUGIN MANAGE.
my $PluginNeedAWStatsVersion="6.2";
my $PluginHooksFunctions="AddHTMLMenuLink AddHTMLGraph ShowInfoHost SectionInitHashArray SectionProcessIp SectionProcessHostname SectionReadHistory SectionWriteHistory";
my $PluginName="geoip_isp_maxmind";
my $LoadedOverride=0;
my $OverrideFile="";
my %TmpDomainLookup; 
# ----->

# <-----
# IF YOUR PLUGIN NEED GLOBAL VARIABLES, THEY MUST BE DECLARED HERE.
use vars qw/
$geoip_isp_maxmind
%_isp_p
%_isp_h
%_isp_k
%_isp_l
$MAXNBOFSECTIONGIR
$MAXLENGTH
/;
# ----->


#-----------------------------------------------------------------------------
# PLUGIN FUNCTION: Init_pluginname
#-----------------------------------------------------------------------------
sub Init_geoip_isp_maxmind {
	my $InitParams=shift;
	my $checkversion=&Check_Plugin_Version($PluginNeedAWStatsVersion);
    $MAXNBOFSECTIONGIR=10;
    $MAXLENGTH=20;

	# <-----
	# ENTER HERE CODE TO DO INIT PLUGIN ACTIONS
	debug(" Plugin $PluginName: InitParams=$InitParams",1);
   	my ($mode,$datafile,$override)=split(/\s+/,$InitParams,3);
   	if (! $datafile) { $datafile="GeoIPIsp.dat"; }
	if ($type eq 'geoippureperl') {
		# With pureperl with always use GEOIP_STANDARD.
		# GEOIP_MEMORY_CACHE seems to fail with ActiveState
		if ($mode eq '' || $mode eq 'GEOIP_MEMORY_CACHE')  { $mode=Geo::IP::PurePerl::GEOIP_STANDARD(); }
		else { $mode=Geo::IP::PurePerl::GEOIP_STANDARD(); }
	} else {
		if ($mode eq '' || $mode eq 'GEOIP_MEMORY_CACHE')  { $mode=Geo::IP::GEOIP_MEMORY_CACHE(); }
		else { $mode=Geo::IP::GEOIP_STANDARD(); }
	}
	if ($override){$OverrideFile=$override;}
	%TmpDomainLookup=();
	debug(" Plugin $PluginName: GeoIP initialized type=$type mode=$mode",1);
	if ($type eq 'geoippureperl') {
		$geoip_isp_maxmind = Geo::IP::PurePerl->open($datafile, $mode);
	} else {
		$geoip_isp_maxmind = Geo::IP->open($datafile, $mode);
	}
	$LoadedOverride=0;
# Fails on some GeoIP version
# 	debug(" Plugin geoip_isp_maxmind: GeoIP initialized database_info=".$geoip_isp_maxmind->database_info());
	# ----->

	return ($checkversion?$checkversion:"$PluginHooksFunctions");
}


#-----------------------------------------------------------------------------
# PLUGIN FUNCTION: AddHTMLMenuLink_pluginname
# UNIQUE: NO (Several plugins using this function can be loaded)
#-----------------------------------------------------------------------------
sub AddHTMLMenuLink_geoip_isp_maxmind {
    my $categ=$_[0];
    my $menu=$_[1];
    my $menulink=$_[2];
    my $menutext=$_[3];
	# <-----
	if ($Debug) { debug(" Plugin $PluginName: AddHTMLMenuLink"); }
    if ($categ eq 'who') {
        $menu->{"plugin_$PluginName"}=0.6;              # Pos
        $menulink->{"plugin_$PluginName"}=2;          # Type of link
        $menutext->{"plugin_$PluginName"}="ISP";      # Text
    }
	# ----->
	return 0;
}


#-----------------------------------------------------------------------------
# PLUGIN FUNCTION: AddHTMLGraph_pluginname
# UNIQUE: NO (Several plugins using this function can be loaded)
#-----------------------------------------------------------------------------
sub AddHTMLGraph_geoip_isp_maxmind {
    my $categ=$_[0];
    my $menu=$_[1];
    my $menulink=$_[2];
    my $menutext=$_[3];
	# <-----
    my $ShowISP='H';
	$MinHit{'Isp'}=1;
	my $total_p; my $total_h; my $total_k;
	my $rest_p; my $rest_h; my $rest_k;

	if ($Debug) { debug(" Plugin $PluginName: AddHTMLGraph $categ $menu $menulink $menutext"); }
	my $title='ISP';
	&tab_head("$title",19,0,'isp');
	print "<tr bgcolor=\"#$color_TableBGRowTitle\"><th>ISP : ".((scalar keys %_isp_h)-($_isp_h{'unknown'}?1:0))."</th>";
	if ($ShowISP =~ /P/i) { print "<th bgcolor=\"#$color_p\" width=\"80\">$Message[56]</th>"; }
	if ($ShowISP =~ /P/i) { print "<th bgcolor=\"#$color_p\" width=\"80\">$Message[15]</th>"; }
	if ($ShowISP =~ /H/i) { print "<th bgcolor=\"#$color_h\" width=\"80\">$Message[57]</th>"; }
	if ($ShowISP =~ /H/i) { print "<th bgcolor=\"#$color_h\" width=\"80\">$Message[15]</th>"; }
	if ($ShowISP =~ /B/i) { print "<th bgcolor=\"#$color_k\" width=\"80\">$Message[75]</th>"; }
	if ($ShowISP =~ /L/i) { print "<th width=\"120\">$Message[9]</th>"; }
	print "</tr>\n";
	$total_p=$total_h=$total_k=0;
	my $count=0;
	&BuildKeyList($MaxRowsInHTMLOutput,$MinHit{'Isp'},\%_isp_h,\%_isp_h);
    	foreach my $key (@keylist) {
            if ($key eq 'unknown') { next; }
   			my $p_p; my $p_h;
   			if ($TotalPages) { $p_p=int($_isp_p{$key}/$TotalPages*1000)/10; }
   			if ($TotalHits)  { $p_h=int($_isp_h{$key}/$TotalHits*1000)/10; }
   		    print "<tr>";
   		    my $isp=$key; $isp =~ s/_/ /g;
   		    print "<td class=\"aws\">".ucfirst($isp)."</td>";
    		if ($ShowISP =~ /P/i) { print "<td>".($_isp_p{$key}?Format_Number($_isp_p{$key}):"&nbsp;")."</td>"; }
    		if ($ShowISP =~ /P/i) { print "<td>".($_isp_p{$key}?"$p_p %":'&nbsp;')."</td>"; }
    		if ($ShowISP =~ /H/i) { print "<td>".($_isp_h{$key}?Format_Number($_isp_h{$key}):"&nbsp;")."</td>"; }
    		if ($ShowISP =~ /H/i) { print "<td>".($_isp_h{$key}?"$p_h %":'&nbsp;')."</td>"; }
    		if ($ShowISP =~ /B/i) { print "<td>".Format_Bytes($_isp_k{$key})."</td>"; }
    		if ($ShowISP =~ /L/i) { print "<td>".($_isp_p{$key}?Format_Date($_isp_l{$key},1):'-')."</td>"; }
    		print "</tr>\n";
    		$total_p += $_isp_p{$key}||0;
    		$total_h += $_isp_h{$key};
    		$total_k += $_isp_k{$key}||0;
    		$count++;
    	}
	if ($Debug) { debug("Total real / shown : $TotalPages / $total_p - $TotalHits / $total_h - $TotalBytes / $total_h",2); }
	$rest_p=0;
	$rest_h=$TotalHits-$total_h;
	$rest_k=0;
	if ($rest_p > 0 || $rest_h > 0 || $rest_k > 0) {	# All other cities
#	    print "<tr>";
#	    print "<td class=\"aws\">&nbsp;</td>";
#   		if ($ShowISP =~ /P/i) { print "<td>&nbsp;</td>"; }
#   		if ($ShowISP =~ /P/i) { print "<td>&nbsp;</td>"; }
#   		if ($ShowISP =~ /H/i) { print "<td>&nbsp;</td>"; }
#   		if ($ShowISP =~ /H/i) { print "<td>&nbsp;</td>"; }
#   		if ($ShowISP =~ /B/i) { print "<td>&nbsp;</td>"; }
#   		if ($ShowISP =~ /L/i) { print "<td>&nbsp;</td>"; }
#        print "</tr>\n";

		my $p_p; my $p_h;
		if ($TotalPages) { $p_p=int($rest_p/$TotalPages*1000)/10; }
		if ($TotalHits)  { $p_h=int($rest_h/$TotalHits*1000)/10; }
		print "<tr>";
		print "<td class=\"aws\"><span style=\"color: #$color_other\">$Message[2]/$Message[0]</span></td>";
		if ($ShowISP =~ /P/i) { print "<td>".($rest_p?Format_Number($rest_p):"&nbsp;")."</td>"; }
   		if ($ShowISP =~ /P/i) { print "<td>".($rest_p?"$p_p %":'&nbsp;')."</td>"; }
		if ($ShowISP =~ /H/i) { print "<td>".($rest_h?Format_Number($rest_h):"&nbsp;")."</td>"; }
   		if ($ShowISP =~ /H/i) { print "<td>".($rest_h?"$p_h %":'&nbsp;')."</td>"; }
		if ($ShowISP =~ /B/i) { print "<td>".Format_Bytes($rest_k)."</td>"; }
		if ($ShowISP =~ /L/i) { print "<td>&nbsp;</td>"; }
		print "</tr>\n";
	}
	&tab_end();

	# ----->
	return 0;
}


#-----------------------------------------------------------------------------
# PLUGIN FUNCTION: ShowInfoHost_pluginname
# UNIQUE: NO (Several plugins using this function can be loaded)
# Function called to add additionnal columns to the Hosts report.
# This function is called when building rows of the report (One call for each
# row). So it allows you to add a column in report, for example with code :
#   print "<TD>This is a new cell for $param</TD>";
# Parameters: Host name or ip
#-----------------------------------------------------------------------------
sub ShowInfoHost_geoip_isp_maxmind {
    my $param="$_[0]";
	# <-----
	if ($param eq '__title__') {
    	my $NewLinkParams=${QueryString};
    	$NewLinkParams =~ s/(^|&|&amp;)update(=\w*|$)//i;
    	$NewLinkParams =~ s/(^|&|&amp;)output(=\w*|$)//i;
    	$NewLinkParams =~ s/(^|&|&amp;)staticlinks(=\w*|$)//i;
    	$NewLinkParams =~ s/(^|&|&amp;)framename=[^&]*//i;
    	my $NewLinkTarget='';
    	if ($DetailedReportsOnNewWindows) { $NewLinkTarget=" target=\"awstatsbis\""; }
    	if (($FrameName eq 'mainleft' || $FrameName eq 'mainright') && $DetailedReportsOnNewWindows < 2) {
    		$NewLinkParams.="&framename=mainright";
    		$NewLinkTarget=" target=\"mainright\"";
    	}
    	$NewLinkParams =~ s/(&amp;|&)+/&amp;/i;
    	$NewLinkParams =~ s/^&amp;//; $NewLinkParams =~ s/&amp;$//;
    	if ($NewLinkParams) { $NewLinkParams="${NewLinkParams}&"; }

		print "<th width=\"80\">";
        print "<a href=\"".($ENV{'GATEWAY_INTERFACE'} || !$StaticLinks?XMLEncode("$AWScript?${NewLinkParams}output=plugin_$PluginName"):"$StaticLinks.plugin_$PluginName.$StaticExt")."\"$NewLinkTarget>GeoIP<br />ISP</a>";
        print "</th>";
	}
	elsif ($param) {
		# try loading our override file if we haven't yet
		if (!$LoadedOverride){&LoadOverrideFile_geoip_isp_maxmind();}
        my $ip=0;
		my $key;
		if ($param =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/) {	# IPv4 address
		    $ip=4;
			$key=$param;
		}
		elsif ($param =~ /^[0-9A-F]*:/i) {						# IPv6 address
		    $ip=6;
			$key=$param;
		}
		print "<td>";
		if ($key && $ip==4) {
        	my $isp;
    		if ($geoip_isp_maxmind){$isp = $TmpDomainLookup{$geoip_isp_maxmind->get_ip_address($param)};}
    		else {$isp = $TmpDomainLookup{$param};}
        	if (!$isp && $type eq 'geoippureperl')
			{
        		# Function isp_by_addr does not exists in PurePerl but isp_by_name do same
        		$isp=$geoip_isp_maxmind->isp_by_name($param) if $geoip_isp_maxmind;
        	}
        	elsif (!$isp)
        	{
        		# Function isp_by_addr does not exits, so we use org_by_addr
        		$isp=$geoip_isp_maxmind->org_by_addr($param) if $geoip_isp_maxmind;
        	}
        	if ($Debug) { debug("  Plugin $PluginName: GetIspByIp for $param: [$isp]",5); }
		    if ($isp) {
		        if (length($isp) <= $MAXLENGTH) {
		            print "$isp";
		        }
		        else {
		            print substr($isp,0,$MAXLENGTH).'...';
		        }
		    }
		    else { print "<span style=\"color: #$color_other\">$Message[0]</span>"; }
		}
		if ($key && $ip==6) {
		    print "<span style=\"color: #$color_other\">$Message[0]</span>";
		}
		if (! $key) {
        	my $isp;
    		if ($geoip_isp_maxmind){$isp = $TmpDomainLookup{$geoip_isp_maxmind->get_ip_address($param)};}
    		else {$isp = $TmpDomainLookup{$param};}
        	if (!$isp && $type eq 'geoippureperl')
			{
        		$isp=$geoip_isp_maxmind->isp_by_name($param) if $geoip_isp_maxmind;
        	}
        	elsif (!$isp)
        	{
        		$isp=$geoip_isp_maxmind->isp_by_name($param) if $geoip_isp_maxmind;
        	}
        	if ($Debug) { debug("  Plugin $PluginName: GetIspByHostname for $param: [$isp]",5); }
		    if ($isp) {
		        if (length($isp) <= $MAXLENGTH) {
		            print "$isp";
		        }
		        else {
		            print substr($isp,0,$MAXLENGTH).'...';
		        }
		    }
		    else { print "<span style=\"color: #$color_other\">$Message[0]</span>"; }
		}
		print "</td>";
	}
	else {
		print "<td>&nbsp;</td>";
	}
	return 1;
	# ----->
}


#-----------------------------------------------------------------------------
# PLUGIN FUNCTION: SectionInitHashArray_pluginname
# UNIQUE: NO (Several plugins using this function can be loaded)
#-----------------------------------------------------------------------------
sub SectionInitHashArray_geoip_isp_maxmind {
#    my $param="$_[0]";
	# <-----
	if ($Debug) { debug(" Plugin $PluginName: Init_HashArray"); }
	%_isp_p = %_isp_h = %_isp_k = %_isp_l =();
	# ----->
	return 0;
}


#-----------------------------------------------------------------------------
# PLUGIN FUNCTION: SectionProcessIP_pluginname
# UNIQUE: NO (Several plugins using this function can be loaded)
#-----------------------------------------------------------------------------
sub SectionProcessIp_geoip_isp_maxmind {
    my $param="$_[0]";      # Param must be an IP
	# <-----
	if (!$LoadedOverride){&LoadOverrideFile_geoip_isp_maxmind();}
	my $isp;
    if ($geoip_isp_maxmind){$isp = $TmpDomainLookup{$geoip_isp_maxmind->get_ip_address($param)};}
    else {$isp = $TmpDomainLookup{$param};}
	if (!$isp && $type eq 'geoippureperl')
	{
		# Function isp_by_addr does not exists in PurePerl but isp_by_name do same
		$isp=$geoip_isp_maxmind->isp_by_name($param) if $geoip_isp_maxmind;
	}
	elsif(!$isp)
	{
        # Function isp_by_addr does not exits, so we use org_by_addr
		$isp=$geoip_isp_maxmind->org_by_addr($param) if $geoip_isp_maxmind;
	}
	if ($Debug) { debug("  Plugin $PluginName: GetIspByIp for $param: [$isp]",5); }
    if ($isp) {
        $isp =~ s/\s/_/g;
        $_isp_h{$isp}++;
    } else {
        $_isp_h{'unknown'}++;
    }
#	if ($timerecord > $_isp_l{$city}) { $_isp_l{$city}=$timerecord; }
	# ----->
	return;
}


#-----------------------------------------------------------------------------
# PLUGIN FUNCTION: SectionProcessHostname_pluginname
# UNIQUE: NO (Several plugins using this function can be loaded)
#-----------------------------------------------------------------------------
sub SectionProcessHostname_geoip_isp_maxmind {
    my $param="$_[0]";      # Param must be an IP
	# <-----
	if (!$LoadedOverride){&LoadOverrideFile_geoip_isp_maxmind();}
	my $isp;
    if ($geoip_isp_maxmind){$isp = $TmpDomainLookup{$geoip_isp_maxmind->get_ip_address($param)};}
    else {$isp = $TmpDomainLookup{$param};}
	if (!$isp && $type eq 'geoippureperl')
	{
		$isp=$geoip_isp_maxmind->isp_by_name($param) if $geoip_isp_maxmind;
	}
	elsif(!$isp)
	{
		$isp=$geoip_isp_maxmind->isp_by_name($param) if $geoip_isp_maxmind;
	}
	if ($Debug) { debug("  Plugin $PluginName: GetIspByHostname for $param: [$isp]",5); }
    if ($isp) {
        $isp =~ s/\s/_/g;
        $_isp_h{$isp}++;
    } else {
        $_isp_h{'unknown'}++;
    }
#	if ($timerecord > $_isp_l{$city}) { $_isp_l{$city}=$timerecord; }
	# ----->
	return;
}


#-----------------------------------------------------------------------------
# PLUGIN FUNCTION: SectionReadHistory_pluginname
# UNIQUE: NO (Several plugins using this function can be loaded)
#-----------------------------------------------------------------------------
sub SectionReadHistory_geoip_isp_maxmind {
    my $issectiontoload=shift;
    my $xmlold=shift;
    my $xmleb=shift;
	my $countlines=shift;
	# <-----
	if ($Debug) { debug(" Plugin $PluginName: Begin of PLUGIN_$PluginName section"); }
	my @field=();
	my $count=0;my $countloaded=0;
	do {
		if ($field[0]) {
			$count++;
			if ($issectiontoload) {
				$countloaded++;
				if ($field[2]) { $_isp_h{$field[0]}+=$field[2]; }
			}
		}
		$_=<HISTORY>;
		chomp $_; s/\r//;
		@field=split(/\s+/,($xmlold?XMLDecodeFromHisto($_):$_));
		$countlines++;
	}
	until ($field[0] eq "END_PLUGIN_$PluginName" || $field[0] eq "${xmleb}END_PLUGIN_$PluginName" || ! $_);
	if ($field[0] ne "END_PLUGIN_$PluginName" && $field[0] ne "${xmleb}END_PLUGIN_$PluginName") { error("History file is corrupted (End of section PLUGIN not found).\nRestore a recent backup of this file (data for this month will be restored to backup date), remove it (data for month will be lost), or remove the corrupted section in file (data for at least this section will be lost).","","",1); }
	if ($Debug) { debug(" Plugin $PluginName: End of PLUGIN_$PluginName ($count entries, $countloaded loaded)"); }
	# ----->
	return 0;
}

#-----------------------------------------------------------------------------
# PLUGIN FUNCTION: SectionWriteHistory_pluginname
# UNIQUE: NO (Several plugins using this function can be loaded)
#-----------------------------------------------------------------------------
sub SectionWriteHistory_geoip_isp_maxmind {
    my ($xml,$xmlbb,$xmlbs,$xmlbe,$xmlrb,$xmlrs,$xmlre,$xmleb,$xmlee)=(shift,shift,shift,shift,shift,shift,shift,shift,shift);
    if ($Debug) { debug(" Plugin $PluginName: SectionWriteHistory_$PluginName start - ".(scalar keys %_isp_h)); }
	# <-----
	print HISTORYTMP "\n";
	if ($xml) { print HISTORYTMP "<section id='plugin_$PluginName'><sortfor>$MAXNBOFSECTIONGIR</sortfor><comment>\n"; }
	print HISTORYTMP "# Plugin key - Pages - Hits - Bandwidth - Last access\n";
	#print HISTORYTMP "# The $MaxNbOfExtra[$extranum] first number of hits are first\n";
	$ValueInFile{"plugin_$PluginName"}=tell HISTORYTMP;
	print HISTORYTMP "${xmlbb}BEGIN_PLUGIN_$PluginName${xmlbs}".(scalar keys %_isp_h)."${xmlbe}\n";
	&BuildKeyList($MAXNBOFSECTIONGIR,1,\%_isp_h,\%_isp_h);
	my %keysinkeylist=();
	foreach (@keylist) {
		$keysinkeylist{$_}=1;
		#my $page=$_isp_p{$_}||0;
		#my $bytes=$_isp_k{$_}||0;
		#my $lastaccess=$_isp_l{$_}||'';
		print HISTORYTMP "${xmlrb}$_${xmlrs}0${xmlrs}", $_isp_h{$_}, "${xmlrs}0${xmlrs}0${xmlre}\n"; next;
	}
	foreach (keys %_isp_h) {
		if ($keysinkeylist{$_}) { next; }
		#my $page=$_isp_p{$_}||0;
		#my $bytes=$_isp_k{$_}||0;
		#my $lastaccess=$_isp_l{$_}||'';
		print HISTORYTMP "${xmlrb}$_${xmlrs}0${xmlrs}", $_isp_h{$_}, "${xmlrs}0${xmlrs}0${xmlre}\n"; next;
	}
	print HISTORYTMP "${xmleb}END_PLUGIN_$PluginName${xmlee}\n";
	# ----->
	return 0;
}

#-----------------------------------------------------------------------------
# PLUGIN FUNCTION: LoadOverrideFile
# Attempts to load a comma delimited file that will override the GeoIP database
# Useful for Intranet records
# CSV format: IP,"isp"
#-----------------------------------------------------------------------------
sub LoadOverrideFile_geoip_isp_maxmind{
	my $filetoload="";
	if ($OverrideFile){
		if (!open(GEOIPFILE, $OverrideFile)){
			debug("Plugin $PluginName: Unable to open override file: $OverrideFile");
			$LoadedOverride = 1;
			return;
		}
	}else{
		my $conf = (exists(&Get_Config_Name) ? Get_Config_Name() : $SiteConfig);
		if ($conf && open(GEOIPFILE,"$DirData/$PluginName.$conf.txt"))	{ $filetoload="$DirData/$PluginName.$conf.txt"; }
		elsif (open(GEOIPFILE,"$DirData/$PluginName.txt"))	{ $filetoload="$DirData/$PluginName.txt"; }
		else { debug("Did not find $PluginName file \"$DirData/$PluginName.txt\": $!"); }
	}
	# This is the fastest way to load with regexp that I know
	while (<GEOIPFILE>){
		chomp $_;
		s/\r//;
		my @record = split(",", $_);
		# replace quotes if they were used in the file
		foreach (@record){ $_ =~ s/"//g; }
		# store in hash
		$TmpDomainLookup{$record[0]} = $record[1];
	}
	close GEOIPFILE;
	$LoadedOverride = 1;
	debug(" Plugin $PluginName: Overload file loaded: ".(scalar keys %TmpDomainLookup)." entries found.");
	return;
}

1;	# Do not remove this line
