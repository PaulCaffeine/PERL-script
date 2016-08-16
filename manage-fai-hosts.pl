#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Std;

use Pod::Usage;
#pod2usage( -verbose => 1);


=head1 NAME

    manage-fai-hosts.pl - skrypt do zarządzania konfiguracją hostów 
    systemu FAI

=head1 SYNOPSIS

    manage-fai-hosts.pl [ -f config] -g|d|l 
    manage-fai-hosts.pl	-m -g  
    manage-fai-hosts.pl	-m -a newhost -s classhost 
    manage-fai-hosts.pl -m -r samplehost 
    manage-fai-hosts.pl -m -a newhost -C "classes" 
    manage-fai-hosts.pl -r host 
    manage-fai-hosts.pl -a newhost -s classhost [-p password] [-i ip] 
    manage-fai-hosts.pl -a host  
    manage-fai-hosts.pl -c host   

=head1 DESCRIPTION 

   Skrypt manage-fai-hosts.pl pozwala na zarządzanie konfiguracją hostów
   wykorzystywanych przez system FAI, a także konfiguracją samego systemu.
   W ramach zarządzania konfiguracją hostów pozwala na wygenerowanie i
   przypisanie adresów IP i adresów MAC, na dodanie ich wraz z nazwami
   hostów do konfiguracji usługi DHCP i pliku /etc/hosts, a także na
   utworzenie plików dla środowiska PXE. W oparciu o domyślny szablon
   generowany jest także plik (w formacie XML) niezbędny do zdefiniowania
   maszyny wirtualnej w środowisku KVM. W ramach zarządzania konfiguracją
   systemu FAI skrypt pozwala na dodawanie i usuwanie hostów w menu systemu
   FAI oraz na definiowanie hasła dla użytkownika root na maszynie
   klienckiej.

=head1 OPTIONS

=over 1

=item B<-c> host

    usuwa hosta z konfiguracji FAI w razie niepełnej lub
    błędnej definicji


=item B<-d>

    tworzy plik /etc/dhcp/dhcpd.conf w oparciu o wartości
    zmiennych zdefiniowanych w skrypcie lub w pliku konfiguracyjnym
    określonym przez opcję -f (domyślnie ~/.fairc)

=item B<-f> config

    definiuje położenie pliku konfiguracyjnego (zob. opcje -d i -g)

=item B<-g>

    tworzy wzorcowy plik konfiguracyjny ~/.fairc w oparciu o
    wartości zapisane w skrypcie

=item B<-h>

    wypisuje pomoc

=item B<-l>

    wypisuje nazwy hostów wraz z przypisanymi do nich klasami
    (tzw. menu FAI)

=item B<-m> B<-g>

    tworzy plik definiujący menu FAI zgodne z wymaganiami skryptów
    tego systemu (usuwa komentarze i instrukcje warunkowe)

=item B<-m> B<-a> newhost B<-s> classhost

    dodaje do menu FAI nowego hosta wzorowanego na już istniejącym

=item B<-m> B<-r> host

    usuwa wybranego hosta z menu FAI

=item B<-m> B<-a> newhost B<-C> "classes"

    definiuje nowego hosta wraz przypisanymi mu klasami w menu FAI

=item B<-r> host

    usuwa hosta z menu FAI i konfiguracji systemu

=item B<-a> host

    dodawanie hosta zdefiniowanego w menu FAI do konfiguracji systemu

=item B<-a> newhost B<-s> classhost B<-p> password B<-i> ip

    dodaje nowego hosta do menu FAI i konfiguracji systemu


=back

=head1 EXAMPLES

=over 1

=item *

Dodawanie hosta c7server do menu systemu FAI wzorowanego na faiserver:

    manage-fai-hosts.pl -m -a c7server -s faiserver

=item *

Usuwanie hosta demohost z menu systemu FAI:

    manage-fai-hosts.pl -m -r demohost

=item *

Dodawanie hosta c7min z przypisanymi do niego klasami "FAIBASE DHCPC 
CENTOS7" do menu systemu FAI:

    manage-fai-hosts.pl -m -a c7min -C "FAIBASE DHCPC CENTOS7"

=item *

Usuwanie hosta c7min z menu systemu FAI i jego konfiguracji: 

    manage-fai-hosts.pl -r c7min


=item *    

Usuwanie hosta c7min z konfiguracji systemu FAI w razie niepełnej
definicji:

    manage-fai-hosts.pl -c c7min


=item *

Dodawanie hosta c7min wzorowanego na hoście demohost z adresem 
192.168.43.5 i hasłem "fai":

    manage-fai-hosts.pl -a c7min -s demohost -i 192.168.43.5 -p fai

=back



=head1 AUTHORS

    Paweł Paczkowski <259043@fizyka.umk.pl>	

=head1 COPYRIGHT

    Copyright 2016, Jacek Kobus, Paweł Paczkowski.
    Oprogramowanie może być rozpowszechniane na takich samych
    warunkach jak Perl.

=cut


getopts('hgvc:f:dls:r:a:i:p:mlC:');

our ($opt_h,$opt_g,$opt_f,$opt_v,$opt_c,$opt_d,$opt_l,$opt_s,$opt_r,$opt_a,$opt_i,$opt_p,$opt_m,$opt_C);

###############################################################################
####################   Defining variables   ###################################
###############################################################################

my $conf;

#----------------------conf----------------------------------------------------#

if ( -e $ENV{"HOME"} ) {

$conf = $ENV{"HOME"}."/.fairc"; #file with variables

} 

else {

print "Error! Variable \$ENV{\"HOME\"} does not exist for your user. Please contact system administrator\n";
exit 0;

}

#------------------------help--------------------------------------------------#

if ($opt_h) {

pod2usage( -verbose => 1);
exit 0;

}


#------------------------sample file with variables----------------------------#

if ($opt_g && !$opt_m) {

&createSampleVars($conf);
}


#-----------------------choose file with variables-----------------------------#

if ($opt_f && -e $opt_f) {

$conf=$opt_f;
print "\nConfig file: $conf\n";
}

elsif (-e $conf) {
if ($opt_v) {
print "\nConfig file: $conf\n";
}
}
else {

print "Error. Config file wasn't defined\n";
exit 0;

}

#------------------------------------------------------------------------------#

my $dhcpd = "/etc/dhcp/dhcpd.conf"; #dhcp config
my $hosts = "/etc/hosts"; #hosts


my $vars=&defineVars($conf); #hash with variables
my %vars=%$vars; 


if (scalar keys %vars ne 16 ) { 

print "Error. Please, define all variables in $conf\n"; 
exit 0; 

}


my $pwdDefault = $vars{rootpwd};
my $pwdDir = $vars{rootpwddir};
my $domain = $vars{domain};
my $pxeDir = $vars{pxeconfig};
my $tftp = $vars{tftpfiles};
my $faiMenu = $vars{faimenu};
my $xml = $vars{vmxml};
my $serverName = $vars{servername};

(my $serverIP,$serverName)=&getHostsParams($serverName);
if (!$serverIP && !$serverName) {
	print "Error! $serverName doesn't exists in $hosts\n";
	exit 0;
}

################################################################################
###############################   MENU    ######################################
################################################################################

#---------------------format fai-menu------------------------------------------#

if ($opt_g && $opt_m) {

&formatFaimenu();

}


#--------------------show fai-menu---------------------------------------------#

if ($opt_l) {

#print "##############################################################\n";
print "\n";
print "Minimal diskspace required: UBUNTU/CENTOS - 4GB, FEDORA - 5GB\n";
print "\n";
print "List of hosts and related classes:\n\n";

&showMenu();

}


#------------------add host in fai-menu----------------------------------------#

if ($opt_m && $opt_a && $opt_s) {

&addLikeHostInMenu($opt_s,$opt_a);

}

#-----------------remove host in fai-menu--------------------------------------#

if ($opt_m && $opt_r) {

&removeHostInMenu($opt_r);

}

#----------------define host with classes in fai-menu--------------------------#

if ($opt_m && $opt_a && $opt_C) {

&addNewHostInMenu($opt_a,$opt_C);

}


#--------------remove host from fai-menu and configuration---------------------#

if ($opt_r && !$opt_m) {

my ($ip,$hostname) = &getHostsParams($opt_r); #get ip and hostname

if (!$ip || !$hostname) { 
	print "Error! $opt_r does not exists in $hosts\nn";
	exit 0; 
}

	if ($hostname eq $serverName) { 
	print "You can't remove FAI server\n"; 
	exit 0; 
	}
	else {
	my ($n,$h)=&readDhcp();
	my %network=%$n; 
	my @hosts=@$h;

		if (!&checkIP($ip,\@hosts)) {
		my $hex=&ip2hex($ip);

		if (!&removeHostFromDhcp($ip,$hostname)) {
			if ($opt_v) {
			print "\n";
			printf "1: %-45s %s %-8s\n", $dhcpd, "-", "modified";
			}
		} 
		else {
			print "1: Error! $hostname cannot be removed from $dhcpd\n";
		}
		if (!&removeHostFromHosts($ip,$hostname)) {
			if ($opt_v) {
			printf "2: %-45s %s %-8s\n", $hosts, "-", "modified";
			}
		}
		else {
			print "2: Error! $hostname cannot be removed from $hosts\n";
		}

		if (!system("rm $pxeDir/$hex")) { 
			if ($opt_v) {
			my $pxeFile = "$pxeDir/$hex";
			printf "3: %-45s %s %-8s\n", $pxeFile, "-", "removed";
			}
		}
		else { 
			print "3: Error! PXEfile $hex cannot be removed for $ip\n"; 
			exit 0;
		}
		if (!system("rm $pxeDir/$ip")) { 
			if ($opt_v) {
			my $linkFile = "$pxeDir/$ip";
        		printf "4: %-45s %s %-8s\n", $linkFile, "-", "removed";
			}
		}
		else { 
			print "4: Error! Link cannot be removed for $ip\n";
			exit 0;
		} 
		if (!system("rm $xml/$hostname.xml")) {
			if ($opt_v) {
			my $xmlFile = "$xml/$hostname.xml";
        		printf "5: %-45s %s %-8s\n", $xmlFile, "-", "removed";
			}
		}
		else { 
			print "5: Error! XML cannot be removed from $xml\n";
			exit 0;
		}
			&removeHostInMenu($hostname);
			print "Host $hostname removed: IP=$ip\n\n";
		}
		else {
		print "0: Error! Host $hostname is not in FAI network\n";
		}
	}
}

#------------------check host--------------------------------------------------#

if ($opt_c) {


print "\nChecking $opt_c\n\n";


my ($ip,$hostname) = &getHostsParams($opt_c); #hosts

my ($n,$h)=&readDhcp();
my %network=%$n;
my @hosts=@$h; #dhcp


if ($ip && $hostname) {

print "HOSTNAME=$hostname IP=$ip exists in $hosts\n";

} elsif ($hostname) {
	if (!&checkHostname($hostname,\@hosts)) {
	&clearDhcp($hostname);
	printf "1: %-45s %s %-8s\n", $dhcpd, "-", "cleaned";
	} else {
	printf "1: %-45s %s %-8s\n", $dhcpd, "-", "no entry";
	}
	
	my $xmlFile = "$xml/$hostname.xml";

	if (-e $xmlFile) {
        system("rm $xmlFile");
        printf "2: %-45s %s %-8s\n", $xmlFile, "-", "removed";
	} else {
        printf "2: %-45s %s %-8s\n", $xmlFile, "-", "no file";
	}

} elsif($ip) {
	if (!&checkIP($ip,\@hosts)) {
	&clearDhcp($ip);
	printf "1: %-45s %s %-8s\n", $dhcpd, "-", "cleaned";
	} else {
	printf "1: %-45s %s %-8s\n", $dhcpd, "-", "no entry";
	}

	my $hex=&ip2hex($ip);
	my $pxeFile = "$pxeDir/$hex";

	if ( -e $pxeFile ) {
	system("rm $pxeFile");
	printf "2: %-45s %s %-8s\n", $pxeFile, "-", "cleaned";
	} else {
	printf "2: %-45s %s %-8s\n", $pxeFile, "-", "no file";
	}

	
	
        my $linkFile = "$pxeDir/$ip";

        if ( -l $linkFile) {
        system("rm $linkFile");
        printf "3: %-45s %s %-8s\n", $linkFile, "-", "cleaned";
        } else {
        printf "3: %-45s %s %-8s\n", $linkFile, "-", "no file";
        }

}

else {
	print "Error! Please provide valid IP address and hostname\n";
}
}

#------------------add new host to fai-menu and configuration------------------#

if ($opt_a && !$opt_m) {

my $hostname = $opt_a;

if ($opt_s) {
&addLikeHostInMenu($opt_s,$hostname);
} elsif (!&checkHostInMenu($hostname)) {
  print "Error! Hostname $hostname is not in fai-menu\n";
  exit 0;
}


if ($opt_v) {
print "\nFAI server: HOSTNAME=$serverName IP=$serverIP\n";
}

my $ip;

if ($opt_i) { 
$ip = &getIP($opt_i); 
} 
else { 
$ip = &makeIP(); 
}

my $mac = &makeMac($ip);
my $pwd;

if ($opt_p) {
$pwd=$opt_p;
}
else {
$pwd=$pwdDefault;
}

&makePwd($pwd);



if ($ip && $hostname && $mac) { 

print "Host $hostname added: IP=$ip MAC=$mac PASSWORD=$pwd\n";
print "\n";

}
else {

print "Parameters are not defined\n";
exit 0;

}

#-----------------------------------------------------------------------------#
if ($opt_v && !&addToDhcpNewHost($ip,$hostname,$mac)) {
	printf "1: %-45s %s %-8s\n", $dhcpd, "-", "modified";
}
elsif (&addToDhcpNewHost($ip,$hostname,$mac)) {
	printf "1: %-45s %s %-8s\n", $dhcpd, "-", "error";
}

#-----------------------------------------------------------------------------#
if ($opt_v && !&addToHostsNewHost($ip,$hostname)) {
	printf "2: %-45s %s %-8s\n", $hosts, "-", "modified";
}
elsif (&addToHostsNewHost($ip,$hostname)) {
	printf "2: %-45s %s %-8s\n", $hosts, "-", "error";
}

#-----------------------------------------------------------------------------#

my ($pxe,$link)=&makePxeConfig($ip);
my $pxeFile;
my $linkFile;

if ($opt_v && $pxe) {
	$pxeFile = "$pxeDir/$pxe";
	printf "3: %-45s %s %-8s\n", $pxeFile, "-", "created";
}
elsif (!$pxe) {
	printf "3: Error! PXEfile cannot be created for $ip\n";
}

if ($opt_v && $link) {
	$linkFile = "$pxeDir/$link";
	printf "4: %-45s %s %-8s\n", $linkFile, "-", "created";
}
elsif (!$link) {
	printf "4: Error! Link cannot be created for $ip\n";
}

#-----------------------------------------------------------------------------#

my $xmlFile;

if ($opt_v && &makeXML($hostname,$mac)) {
	$xmlFile = "$xml/$hostname.xml";
	printf "5: %-45s %s %-8s\n", $xmlFile, "-", "created";
}
elsif (!&makeXML($hostname,$mac)) {
	printf "5: XML file $hostname cannot be created in $xml\n";
}


}
#----------------------create dhcp---------------------------------------------#

if ($opt_d) { 

&createDhcp(\%vars); 

} 


################################################################################


sub createSampleVars {

my $filename=shift;

open (FILE, '>', $filename) or die; #warn "$0 $@ $!";

print FILE << "EOM";
#Name=Value #Comment
SUBNET=192.168.43.0
NETMASK=255.255.255.0
ROUTERS=192.168.43.100
DOMAIN=fizyka.umk.pl
DOMAINNAMESERVERS=8.8.8.8
TIMESERVERS=faiserver
NTPSERVERS=faiserver
SERVERNAME=faiserver
ROOTPWD=fai # domy�~[lne has�~Bo
ROOTPWDDIR=/srv/fai/config/class/FAIBASE.var #plik ze zmiennymi i has�~Bem
PXECONFIG=/srv/tftp/fai/pxelinux.cfg #PXE konfiguracja
PXEFILENAME=pxelinux.0
NEXTSERVER=faiserver
TFTPFILES=/srv/tftp/fai #TFTP pliki
FAIMENU=/srv/fai/config/class/50-host-classes #skrypt definuj~Ecy FAI-menu
VMXML=/wheel/TESTS #katalog z plikami XML
EOM
close FILE;
}


sub defineVars {

	my $vars=shift;
	my %vars;
        my @file=&readFile($vars);

        foreach my $row (@file) {
                if ($row =~ /SUBNET=(.+)(\s+)#(.*)/ || $row =~ /SUBNET=(.+)/) { $vars{subnet}=$1;}
                elsif ($row =~ /NETMASK=(.+)(\s+)#(.*)/ || $row =~ /NETMASK=(.+)/) { $vars{netmask}=$1;}
		elsif ($row =~ /ROUTERS=(.+)(\s+)#(.*)/ || $row =~ /ROUTERS=(.+)/) { $vars{routers}=$1; }
		elsif ($row =~ /DOMAIN=(.+)(\s+)#(.*)/ || $row =~ /DOMAIN=(.+)/) { $vars{domain}=$1; }
		elsif ($row =~ /DOMAINNAMESERVERS=(.+)(\s+)#(.*)/ || $row =~ /DOMAINNAMESERVERS=(.+)/) { $vars{domainnameservers}=$1; }
		elsif ($row =~ /TIMESERVERS=(.+)(\s+)#(.*)/ || $row =~ /TIMESERVERS=(.+)/) { $vars{timeservers}=$1; }
		elsif ($row =~ /NTPSERVERS=(.+)(\s+)#(.*)/ || $row =~ /NTPSERVERS=(.+)/) { $vars{ntpservers}=$1; }
		elsif ($row =~ /SERVERNAME=(.+)(\s+)#(.*)/ || $row =~ /SERVERNAME=(.+)/) { $vars{servername}=$1; }
		elsif ($row =~ /ROOTPWD=(.+)(\s+)#(.*)/ || $row =~ /ROOTPWD=(.+)/) { $vars{rootpwd}=$1; }
		elsif ($row =~ /ROOTPWDDIR=(.+)(\s+)#(.*)/ || $row =~ /ROOTPWDDIR=(.+)/) { $vars{rootpwddir}=$1; }
		elsif ($row =~ /PXECONFIG=(.+)(\s+)#(.*)/ || $row =~/PXECONFIG=(.+)/) { $vars{pxeconfig}=$1; }
		elsif ($row =~ /PXEFILENAME=(.+)(\s+)#(.*)/ || $row =~/PXEFILENAME=(.+)/) { $vars{pxefilename}=$1; }
		elsif ($row =~ /NEXTSERVER=(.+)(\s+)#(.*)/ || $row =~/NEXTSERVER=(.+)/) { $vars{nextserver}=$1; }
		elsif ($row =~ /TFTPFILES=(.+)(\s+)#(.*)/ || $row =~ /TFTPFILES=(.+)/) { $vars{tftpfiles}=$1; }
		elsif ($row =~ /FAIMENU=(.+)(\s+)#(.*)/ || $row =~ /FAIMENU=(.+)/) { $vars{faimenu}=$1; }
		elsif ($row =~ /VMXML=(.+)(\s+)#(.*)/ || $row =~ /VMXML=(.+)/) { $vars{vmxml}=$1; }
		else { next; }

}

	return \%vars;
}


sub createPwdScript {


my $scriptPwdDir="/srv/fai/config/scripts/FAIBASE/";
my $script = "10-misc";

if ( -d $scriptPwdDir ) {

my $scriptPwdDefault="$scriptPwdDir/$script";


open (FILE, '>', $scriptPwdDefault) or warn "$0 $@ $!";

print FILE << "EOM";
#!/bin/bash

error=0; trap 'error=\$((\$?>\$error?\$?:\$error))' ERR # save maximum error code

ifclass XORG && {
    fcopy -M /etc/X11/xorg.conf
}

# Set the hostname
if [ -n \$HOSTNAME ]; then
        echo \$HOSTNAME > \$target/etc/hostname
fi

# Create a local admin user
\$ROOTCMD useradd --password \$ROOTPW --groups adm,dialout,cdrom,plugdev,sudo -c "Local Admin,,," --shell /bin/bash demo
\$ROOTCMD mkdir /home/demo
\$ROOTCMD chmod 0700 /home/demo
\$ROOTCMD chown demo:demo /home/demo
fcopy -ir /home/demo

# Basic network configuration
fcopy -v /etc/network/interfaces
EOM

close FILE;
system("chmod u+x $scriptPwdDefault");
}

}


sub makePwd {
	
	my $pwd = shift;
	my @newFile;
	my @file = &readFile($pwdDir);

	my $pwdDec;

	if (chomp($pwdDec = `openssl passwd -1 -salt saltsalt $pwd`)) {

		print "\n";
	}
	else {
		print "Error! You may need to install openssl package\n";
		exit 0;
	}

	foreach my $row (@file) {
		$row =~ s/ROOTPW=\'(.*)\'/ROOTPW=\'$pwdDec\'/g ;
		push @newFile, $row;
	}

	&writeFile($pwdDir,\@newFile);
	&createPwdScript();
}

sub formatFaimenu {

	my @newFile;
	my $filename=$faiMenu;

	my @file = &readFile($filename);

	my $title = "#!/bin/bash\n";
	push @newFile, $title;

	foreach my $row (@file) {

	$row =~ s/#(.*)//g;
	$row =~ s/(.*)ifclass(.*)//g;
	$row =~ s/exit 0//g;
	$row =~ s/^(\s*)(\t*)$//g;

	push @newFile, $row;
}	

	&writeFile($filename,\@newFile);
	print "File $filename was formated\n";

}


sub restartDhcp {

        if ( -e -x "/etc/init.d/isc-dhcp-server") {
        system("/etc/init.d/isc-dhcp-server restart 2>&1 >/dev/null");
        } elsif (-e -x "/etc/init.d/dhcp3-server") {
        system("/etc/init.d/dhcp3-server restart 2>&1 >/dev/null");
        } elsif (-e -x "/etc/init.d/dhcpd") {
        system("/etc/init.d/dhcpd restart 2>&1 >/dev/null");
        } else { print "Error! Please be informed dhcp-server is not installed.\n";}

}

sub addNewHostInMenu {

       my @newFile;
       my $sampleHost=lc(shift);
       my $classes=uc(shift);

       my $filename = $faiMenu;

       my @file = &readFile($faiMenu);

       foreach my $row (@file) {

		$row =~ s/case \$HOSTNAME in(.*)/case \$HOSTNAME in\n\t$sampleHost\)\n\t\techo "$classes" ;;/g ;
		$row =~ s/^(\s*\t*)$//;                

                push @newFile, $row;
        }
       &writeFile($filename,\@newFile);

       print "\nHost added to fai-menu:\n";
       print "$sampleHost = $classes\n\n";
}


sub removeHostInMenu {

        my @newFile;
	my @newFileCheck;

        my $sampleHost=lc(shift);

        my $filename = $faiMenu;

        my @file = &readFile($faiMenu);        
	my $file = "@file";
	my $removed=0;

        foreach my $row (@file) {

                if ($row =~ /\#(.*)$/ || $row =~ s/^(\s*\t*)$//) {
                push @newFile, $row; }
                else {
                if ($row =~ s/\|$sampleHost\|/\|/g) { $removed=$removed+1; }
		if ($row =~ s/\|$sampleHost\)/\)/g) { $removed=$removed+1; }
		if ($row =~ s/$sampleHost\|//g) { $removed=$removed+1; }
                push @newFile, $row;
                }
	}

	if ($removed) {
		&writeFile($filename,\@newFile);
	} else {
		my $content = "@newFile";	
		$content =~ s/(\s*)(\t*)$sampleHost\)(.*)\n(.*)echo(.+);;//g;	
		push @newFileCheck, $content;
 
		my $newFileCheck = "@newFileCheck";
                      
		my $before = $file =~ tr/\n//;
		my $after = $newFileCheck =~ tr/\n//;

    	       if ($before ne $after) {	
	       $removed = 1;
	       &writeFile($filename,\@newFileCheck);	       
	       }
	}
	if ($removed) { 

               print "\nHost removed from fai-menu: ";
               print "$sampleHost\n\n";
	} else {

       	       print "\nHost wasn't removed from fai-menu: ";
               print "$sampleHost\n\n";

       }

}


sub addLikeHostInMenu {

	my @newFile;
	my $sampleHost=lc(shift);
	my $newHost=lc(shift);
	my $filename = $faiMenu;
	my $check;
	my @file = &readFile($faiMenu);	

	foreach my $row (@file) {
	
		if ($row =~ /^\#(.*)$/ || $row =~ s/^(\s*\t*)$//) {
		push @newFile, $row; }
		elsif ($row =~ /^$newHost\|/ || $row =~ /\|$newHost\|/ || $row =~ /$newHost\)/ ) {
		print "$newHost already exists on List\n"; exit 0;
		}
=head
		else {
		if ($row =~ s/\|$sampleHost\|/\|$sampleHost\|$newHost\|/g) { $check=1;}
		if ($row =~ s/\|$sampleHost\)/\|$sampleHost\|$newHost\)/g) { $check=1;}
		if ($row =~ s/^\s*\t*$sampleHost\|/$sampleHost\|$newHost\|/g) { $check=1; }
		if ($row =~ s/^\s*\t*$sampleHost\)/$sampleHost\|$newHost\)/g) { $check=1; }
=cut
		else {
		if ($row =~ s/(.*)$sampleHost(.*)\)/$1$sampleHost$2\|$newHost\)/g)
		{ $check=1; }

		push @newFile, $row;	
		}
	}
	&writeFile($filename,\@newFile);

	if ($check) {
        print "\nHost added to fai-menu: ";
        print "$newHost\n";
        } else {
        print "Error! Host $sampleHost doesn't exist on menu\n\n";
	exit 0;
	}
}


sub checkHostInMenu {

        my $sampleHost=lc(shift);
        my $filename = $faiMenu;
        my @file = &readFile($faiMenu);
	my $result;

        foreach my $row (@file) {

                if ($row =~ /^\#(.*)$/ || $row =~ s/^(\s*\t*)$//) {
                next; }
                elsif ($row =~ /^\s*$sampleHost\|/ || $row =~ /\|$sampleHost\|/ || $row =~ /$sampleHost\)/ ) { 
			return 1;
			last;
                }
		}
			return 0;
}

sub showMenu {

my @file = &readFile($faiMenu);
my @faiMenu;

my $file;


foreach my $row (@file) {
	
	$row =~ s/\#(.*)$//g;
        $row =~ /^\s+$/ ? next : push @faiMenu, $row;
	
}


my $faiMenuContent = "@faiMenu";
my %hostnames;

while ($faiMenuContent =~/(\s*)(.+)\)(.*)\n(.+)echo "(.+)"(.*)/mg) {
		$hostnames{$2}=$5;	
#		printf "   %-30s = %-40s \n", $2,$5;

}

foreach my $host (sort keys %hostnames) {
	printf "   %-30s = %-40s \n", $host,$hostnames{$host};
}

print "\n";

}



sub makeXML {

my $hostname = shift;
my $mac = shift;


open (FILE,"> $xml/$hostname.xml") or die "Could not open file '$xml/$hostname.xml' $!";

print FILE << "EOM";
<domain type='kvm'>
  <name>$hostname</name>
  <memory unit='KiB'>512000</memory>
  <currentMemory unit='KiB'>512000</currentMemory>
  <vcpu placement='static'>1</vcpu>
  <os>
    <type arch='x86_64' machine='rhel6.3.0'>hvm</type>
    <boot dev='hd'/>
    <bootmenu enable='yes' timeout='3000'/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <pae/>
  </features>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>restart</on_crash>
  <devices>
    <emulator>/usr/libexec/qemu-kvm</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='raw' cache='none' io='native'/>
      <source file='/arc-data/images/vm/$hostname.kvm'/>
      <target dev='vda' bus='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x0'/>
    </disk>
    <controller type='usb' index='0'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x2'/>
    </controller>
    <interface type='bridge'>
      <mac address='$mac'/>
      <source bridge='fai0'/>
      <model type='virtio'/>
    </interface>
    <serial type='pty'>
      <target port='0'/>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>
    <input type='tablet' bus='usb'/>
    <input type='mouse' bus='ps2'/>
    <graphics type='vnc' port='-1' autoport='yes'/>
    <video>
      <model type='cirrus' vram='9216' heads='1'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>
    </video>
    <memballoon model='virtio'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>
    </memballoon>
  </devices>
  <seclabel type='none' model='none'/>
</domain>
EOM
close FILE;

return 1;

}



sub ip2hex {

  my $ipadr = shift;
  my $hex = sprintf("%02X%02X%02X%02X", split(/\./,$ipadr));
  return $hex;
}


sub makePxeConfig {

my $initrd=&genPxeVariable("initrd",$tftp);
my $kernel=&genPxeVariable("vmlinuz",$tftp);


my $ip=shift;
my $pxe;
my $link;

my $hex=&ip2hex($ip);


open (FILE,"> $pxeDir/$hex") or die "Could not open file '$pxeDir/$hex' $!";

print FILE << "EOM";
# generated by fai-chboot for host with IP $ip
default fai-generated

label fai-generated
kernel $kernel
append initrd=$initrd ip=dhcp root=/dev/nfs nfsroot=/srv/fai/nfsroot boot=live FAI_FLAGS=verbose,sshd,createvt FAI_ACTION=install FAI_CONFIG_SRC=nfs://$serverIP/srv/fai/config
EOM

close FILE;

$pxe=$hex;

if ( -l "$pxeDir/$ip" || -e "$pxeDir/$ip" ) { 
	system("rm $pxeDir/$ip");
}

if (system("ln -s $pxeDir/$hex $pxeDir/$ip")) { 

$link=0;

}
else
{

$link=$ip;

}

return ($pxe,$link);

}



sub genPxeVariable {


my $name = shift;
my $dir = shift;

opendir(DIR, $dir) || die "Cannot open directory: $dir";
my @files = grep { !/^\.{1,2}$/ }  readdir(DIR);
closedir DIR;

my @test;

if (scalar @files ne 0 ) {
        foreach my $file (@files) {
                if ($file =~ /^$name(.+)/) {
                push @test, $file;
                }
        }

        if (scalar @test eq 0) { return 0;}
        elsif (scalar @test eq 1 ) { return $test[0]; }
        else {
                for (my $i=0;$i< scalar @test; $i++)
                {
                        print $i+1," $test[$i]\n";
                }
		print "Please, remove unused file.\n";
		exit 0;
        }
}
else { print "Error. No files found\n"; 
       exit 0;
}

}

sub verifyHost {


my $ip = shift;
my $hostname = shift;
my $nameWithDomain = join('.',$hostname,$domain);
my $result;
my @content = &readFile($hosts);


foreach my $row (@content) {

if ($row =~ /^$ip\t+(.+)\t*(.*)$/g)
{
   $result=1; last;
}
elsif ($row =~ /^(.+)\t+$nameWithDomain\t*(.*)$/g)
{
   $result=2; last;
}
elsif ($row =~ /^(.+)\t+(.+)\t+$hostname$/g)
{
   $result=3; last;
}
else { next;}
$result=0;
}
return $result;
}



sub writeToHosts {


my ($ip,$hostname) = @_;
my $nameWithDomain = join('.',$hostname,$domain);

open my $fh, ">>$hosts" or die "Could not open file '$hosts' $!";

print $fh "$ip\t$nameWithDomain\t$hostname\n";
close $fh;

return 0;

}


sub addToHostsNewHost {

	my $ip=shift;
	my $hostname=shift;

        my @content = &readFile($hosts);
        my $file = "@content";


	if (&verifyHost($ip,$hostname))
	{
           print "Change values\n";
           print "\n";
	   exit 0;
	}
	else
	{
	   &writeToHosts($ip,$hostname) ? return 1 : return 0;
	}
}



sub createDhcp {


my $vars=shift;
my %vars=%$vars;

if (scalar keys %vars eq 16) {

open (FILE,"> $dhcpd") or warn "$0 $@ $!";

print FILE << "EOM";

ddns-update-style none;
default-lease-time 600;
max-lease-time 7200;
get-lease-hostnames true;

subnet $vars{subnet} netmask $vars{netmask} {

option routers $vars{routers};
option domain-name "$vars{domain}";
option domain-name-servers $vars{domainnameservers};
option time-servers $vars{timeservers};
option ntp-servers $vars{ntpservers};
server-name $vars{servername};
next-server $vars{nextserver};
filename "$vars{pxefilename}";
}
EOM

close FILE;

print "File $dhcpd was generated\n";
&restartDhcp();
}

else { 
	print "Error. Format may be wrong. Please check definition subnet and netmask\n";
	exit 0;

}

}


sub readDhcp {
	
	my $file;
	my @hosts;
	my %network;
	my @content;
	
	@content = &readFile($dhcpd);

	$file = "@content";

	if ($file =~ /subnet (.+) netmask (.+) {/g) {	
	    $network{subnet}=$1; 
	    $network{mask}=$2;
	} else { 
	    print "No network defined\n"; 
	    exit 0;
	} 

	$file = "@content";

	my $index = 0;

	while ($file =~ /host (.+) {hardware ethernet (.+); fixed-address (.+); option host-name \"(.+)\";}/g) { 
	$hosts[$index]{hostname}=$1; 
	$hosts[$index]{mac}=$2;
	$hosts[$index]{ip}=$3;
	$index++; 
	}
	return (\%network,\@hosts);
}


sub makeMac {

	my $firstPart = "54:52:00";
	
	my $ip = shift;

	my ($n,$h)=&readDhcp();
        my %network=%$n; my @hosts=@$h;

	my @ip = split(/\./,$ip);
	my ($firstDig,$secondDig,$thirdDig,$forthDig) = @ip;

	sub addZeros {
	
	my $digit = shift;
	if ( length $digit == 3 ) { print ""; }
	elsif ( length $digit == 2 ) { $digit = "0$digit";  }
	elsif ( length $digit == 1 ) { $digit = "00$digit"; }
	else { print "Error. Number is not defined\n"; exit 0; }
	
	return $digit;

	}
	
	$thirdDig = &addZeros($thirdDig);
	$forthDig = &addZeros($forthDig);	

	my $thirdAndForth = "$thirdDig$forthDig";
	my @thirdAndForth = ( $thirdAndForth =~ m/../g );

	my $secondPart = join(':',@thirdAndForth);
	
	my $mac = "$firstPart:$secondPart";

	
	if (&checkMac($mac,\@hosts)) { print ""; } else { print "Error. Mac is used by other host.\n"; exit 0; }


	return $mac;
	

}


sub checkMac {

        my $mac = shift;
        my $hosts=shift;
        my @hosts=@$hosts;

        for my $i  (0 .. $#hosts) {
        if ($mac eq $hosts[$i]{mac}) { $mac=0; last;
        } else {next;}
        $mac=1;
        }
  return $mac;
}


sub checkHostname {

        my $hostname = shift;
        my $hosts=shift;
        my @hosts=@$hosts;

        for my $i  (0 .. $#hosts) {
        if ($hostname eq $hosts[$i]{hostname}) { $hostname=0; last;
        } else {next;}
        $hostname=1;
        }
  return $hostname;
}


sub checkIP {

 	my $ip = shift;
        my $hosts=shift;
	my @hosts=@$hosts;	

        for my $i  (0 .. $#hosts) {
        if ($ip eq $hosts[$i]{ip} or $ip eq $serverIP) { $ip=0; last;
        } else {next;}
	$ip=1;
        }
  return $ip;
}



sub makeIP {

	my $hostmin;
	my $hostmax;
	my ($n,$h)=&readDhcp();
	my %network=%$n; my @hosts=@$h;
 	my $sipcalc=`sipcalc $network{subnet} $network{mask}`;

	if ($sipcalc =~ /Usable range(.+) (\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(.+) (\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(.*)/)
	{
	$hostmin = "$2.$3.$4.$5"; 
	$hostmax ="$7.$8.$9.$10";

	}
	else { 
	print "Error. You may need to install sipcalc\n"; 
	exit 0;
	}
	
	if ($hostmin && $hostmax) {
	   if ($opt_v) {
           print "FAI network: SUBNET=$network{subnet} NETMASK=$network{mask} HOSTMIN=$hostmin HOSTMAX=$hostmax\n"; }
          }
        else { print "Error. Hostmin and Hostmax are undefined.\n";
exit 0;}	
	
	my $newip;
	my @ipcheck;

	my $ipcheck = $hostmin;
	while (!$newip) {
	if (&checkIP($ipcheck,\@hosts) && !&verifyHost($ipcheck,$ipcheck)) { $newip=$ipcheck; }
	else { 	@ipcheck = split (/\./, $ipcheck);

		my ($firstDig,$secondDig,$thirdDig,$forthDig) = @ipcheck;		
		if ($firstDig > 255 || $secondDig > 255 || $thirdDig > 255 || $forthDig > 255) {
		print "IP Address error\n"; exit 0; }
					
		if ($forthDig < 255) {
		$forthDig = $forthDig + 1;
		}
		elsif ($forthDig == 255 ) {
		$forthDig = 0; $thirdDig = $thirdDig + 1;
		}
		elsif($forthDig == 255 && $thirdDig == 255) {
		$forthDig = 0; $thirdDig = 0; $secondDig = $secondDig + 1;
		}
		elsif($forthDig == 255 && $thirdDig == 255 && $secondDig == 255) {
		$forthDig = 0; $thirdDig = 0; $secondDig = 0; $firstDig = $firstDig + 1;
		}
		else { print "Wrong format\n"; exit 0; }
		
		$ipcheck = "$firstDig.$secondDig.$thirdDig.$forthDig";
	       
	       	if ($ipcheck eq $hostmax ) { 
			print "IP Address equal to Hostmax Ip Address\n"; 
			if (&checkIP($ipcheck,\@hosts) && !&verifyHost($ipcheck,$ipcheck)) { $newip=$ipcheck; }
			else { print "There is no free hosts in network\n";
				exit 0;} }
		else { 
	       	print ""; }
	}
	
	}
	return $newip;	
}




sub writeToDhcp {


my ($ip,$hostname,$mac) = @_;

open (FILE,">> $dhcpd") or die "Could not open file '$dhcpd' $!";
print FILE << "EOM";
host $hostname {hardware ethernet $mac; fixed-address $ip; option host-name "$hostname";}
EOM
close FILE;

return 0;

}




sub addToDhcpNewHost {

my $ip=shift;
my $hostname=shift;
my $mac=shift;

my ($n,$h)=&readDhcp();
my %network=%$n; my @hosts=@$h;

if (!&checkHostname($hostname,\@hosts)) { print "Error. Hostname is used by different hosts\n"; exit 0; }

if (&writeToDhcp($ip,$hostname,$mac)) {
 return 1; 
} else { 
 &restartDhcp();
 return 0;
}

}




sub getIP {

   my $ip = shift;
   my $hostmin;
   my $hostmax;

   $ip =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/ ? print "" : exit 0;

   if(&verifyHost($ip,$ip)) 
    { print "Error. Host with $ip already exists\n"; exit 0; } 
   else {

   my ($n,$h)=&readDhcp();
   my %network=%$n; my @hosts=@$h;

   my $sipcalc=`sipcalc $network{subnet} $network{mask}`;

   if ($sipcalc =~ /Usable range(.+) (\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(.+) (\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(.*)/)
        {
        $hostmin = "$2.$3.$4.$5";
        $hostmax ="$7.$8.$9.$10";

        }
        else {
        print "Error. You may need to install sipcalc\n";
        exit 0;
        }
        
        if ($hostmin && $hostmax) {
	   if ($opt_v) {
	   print "FAI network: SUBNET=$network{subnet} NETMASK=$network{mask} HOSTMIN=$hostmin HOSTMAX=$hostmax\n"; }
	  }
        else { print "Error. Hostmin and Hostmax are undefined.\n";
exit 0;}

   my @ip = split (/\./, $ip);

   my @hostmin = split (/\./, $hostmin);
   my @hostmax = split (/\./, $hostmax);

   my ($first,$second,$third,$forth) = @ip;
   my ($firstMin,$secondMin,$thirdMin,$forthMin) = @hostmin;
   my ($firstMax,$secondMax,$thirdMax,$forthMax) = @hostmax;

   if (($firstMin<=$first && $first<=$firstMax) && ($secondMin<=$second && $second<=$secondMax) && ($thirdMin<=$third && $third<=$thirdMax) && ($forthMin<=$forth && $forth<=$forthMax)) { 
	print "";
} else { print "Error Please edit $hosts. Ip should be from $network{subnet}.\n"; exit 0; }

if (&checkIP($ip,\@hosts) && !&verifyHost($ip,$ip)) { print "";  } else { print "IP is used by other host.\n"; exit 0; }

return $ip;
}
}


sub clearDhcp {

        my $param=shift;
	my ($ip,$hostname);

	($param =~ /(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/) ? $ip = $param : $hostname = $param;

        my @newDhcpd;
        my @content=&readFile($dhcpd);

	if ($ip) {
        foreach my $row (@content) {
                $row =~ /^host (.+) {hardware ethernet (.+); fixed-address $ip; option host-name "(.+)";}$/g ? next : push @newDhcpd, $row;

        }
	}
	elsif($hostname) {
        foreach my $row (@content) {
                $row =~ /^host $hostname {hardware ethernet (.+); fixed-address (.+); option host-name "$hostname";}$/g ? next : push @newDhcpd, $row;

        } 
	} else {
		print "Error! Please user proper format for parameters\n";
		exit 0;
	}


        if (&writeFile($dhcpd,\@newDhcpd)) {
		&restartDhcp();
                return 0;
                #print "$hostname was removed from $dhcpd\n"; 
        } else {
                return 1;
                #print "$hostname was not removed from $dhcpd\n";
        }
}


sub removeHostFromDhcp {

	my $ip=shift;
	my $hostname=shift;
	my @newDhcpd;
	my @content=&readFile($dhcpd);
	
	foreach my $row (@content) {
		$row =~ /^host $hostname {hardware ethernet (.+); fixed-address $ip; option host-name "$hostname";}$/g ? next : push @newDhcpd, $row;
	
	}

	if (&writeFile($dhcpd,\@newDhcpd)) {
		&restartDhcp();
		return 0;
		#print "$hostname was removed from $dhcpd\n"; 
	} else {
		return 1;
		#print "$hostname was not removed from $dhcpd\n";
	}
}


sub getHostsParams {

	my @arg;
	my ($ip, $hostname);
	my $temp = shift;

	my @content = &readFile($hosts);

	($temp =~ /(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/) ? $ip = $temp : $hostname = $temp;
	

	if ($ip) {
	    foreach my $row (@content) {
	    if ($row =~ /^$ip(\t+)([a-zA-Z0-9]+)$/) { push @arg, $2 ; last;
	    }
            elsif ($row =~ /^$ip(\t+)(.+)(\t+)(.+)$/) { push @arg, $4 ; last; }
            else { next; }
           }
#	    if (scalar @arg ne 1 ) { 
#		print "Error. Hostname does not exist or defined incorrectly for $ip\n";  	               exit 0;
#	    }
	    if (scalar @arg ne 1 ) { 
	    
	    $hostname = 0;
	    } else {
	
	    $hostname = $arg[0];
	    }
}

	elsif ($hostname) {
	    foreach my $row (@content) {
	     if ($row =~ /^(.+)(\t+)$hostname\.$domain(\t+)$hostname$/) { push @arg, $1; last;}
             elsif ($row =~ /^(.+)(\t+)$hostname$/) { push @arg, $1; last;
            }
             else { next; }
	   }
#            if (scalar @arg ne 1 ) { 
#                print "Error. IP address does not exist or defined incorrectly for $hostname\n";                     exit 0;
#        }
	    if (scalar @arg ne 1) {
	    
	    $ip=0;
	    } else {

	    $ip=$arg[0];
	}

	}
       return ($ip,$hostname);
}

sub removeHostFromHosts {

        my $ip=shift;
        my $hostname=shift;
        my @newHosts;
        my @content=&readFile($hosts);

        foreach my $row (@content) {
                ($row =~ /^$ip\t+$hostname$/g || $row =~ /^$ip\t+(.+)\t+$hostname$/g) ? next : push @newHosts, $row;

        }

        if (&writeFile($hosts,\@newHosts)) {
		return 0;
		#print "$hostname was removed from $hosts\n" 
	} else {
		return 1;
		#print "$hostname was not removed from $hosts\n";
	}
}





sub readFile {
	
	my $filename = shift;
	my @filecontent;

        open (DATA,"$filename") || die "Impossible to read $filename. $!\n";
        @filecontent = <DATA>;
        close(DATA);

	return @filecontent;
}

sub writeFile {

	my $filename = shift;
	my $filecontent = shift;
	my @filecontent=@$filecontent; 
	open(my $fh, '>', $filename) or die "Impossible to open $filename. $!\n";
	foreach my $row (@filecontent)
	{
		print $fh "$row";
	}
	close $fh;
}

