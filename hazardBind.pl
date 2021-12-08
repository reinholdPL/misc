#!/usr/bin/perl
use XML::Simple;
#use LWP::UserAgent;
use IO::Socket::SSL;
use POSIX qw(strftime);
use Net::IDN::Encode ':all';
 
## www.kazuko.pl
## hazardBind v0.6 [2018-11-30]
## 
## zmodyfikowane 2021-12-08 Dariusz Naurecki Plast-Com
## plik z rejestrem ściagany za pomocą curl'a zamiast biblioteką LWP
 
## START ## USTAWIENIA
 
my $urlHazardXML = "https://hazard.mf.gov.pl/api/Register";             # baza stron hazardowych
my $addressIP = "145.237.235.240";                                      # adres IP na który mają być kierowane zapytania 
my $pathFile = "/etc/bind/named.conf.hazard-redirect";                  # ścieżka do pliku, w której będą domeny hazardowe
my $pathFileZone = "/etc/bind/db.hazard-redirect";                      # ścieżka do pliku ze strefą dla domen hazardowych
my $runCommend = "/etc/init.d/bind9 reload 1> /dev/null 2> /dev/null";  # komenda która będzie uruchamiana, jeśli zostanie coś zmodyfikowane w bazie stron
 
## KONIEC ## USTAWIENIA
 
#my $ua = LWP::UserAgent->new;
#$ua->default_header('Accept-Language' => "pl");
#$ua->ssl_opts(%{{'verify_hostname' => 0, 'SSL_verify_mode' => SSL_VERIFY_NONE}});
 
#my $response = $ua->get($urlHazardXML);
 
 #  if($response->is_success) {
    my $xml = new XML::Simple;
    system(`curl $urlHazardXML -o page.xml`);
    $data = $xml->XMLin('./page.xml');
 
    my $dataNew = "";
    my %isAdd;
       foreach my $domain (@{$data->{'PozycjaRejestru'}}) {
        my $domena = domain_to_ascii($domain->{'AdresDomeny'});
 
           if(!$isAdd{$domena}) { 
               if($domain->{'DataWykreslenia'}) {
                $dataNew .= "# Lp: ".$domain->{'Lp'}."   # dodano: ".$domain->{'DataWpisu'}."   # wykreslono: ".$domain->{'DataWykreslenia'}."\n";
                $dataNew .= "# zone \"$domena\" { type master; file \"$pathFileZone\"; };\n\n";
               } else {
                $dataNew .= "# Lp: ".$domain->{'Lp'}."   # dodano: ".$domain->{'DataWpisu'}."\n";
                $dataNew .= "zone \"$domena\" { type master; file \"$pathFileZone\"; };\n\n";
               }
            $isAdd{$domena} = $domena;
           }
       }
    $dataNew =~ s/^\s+//;
    $dataNew =~ s/\s+$//;
 
    my $dataOld = "";
       if(-e $pathFile) {
        open(UCHWYT, $pathFile);
          while (my $row = <UCHWYT>) { if(!($row =~ /^##\sOstatnia\saktualizacja/)) { $dataOld .= $row; } }
        close (UCHWYT);
        $dataOld =~ s/^\s+//;
        $dataOld =~ s/\s+$//;
       }
 
       if($dataOld ne $dataNew) {
        open(UCHWYT, '>', $pathFile) or die "Nie można otworzyć $pathFile: $!"; 
        print UCHWYT "## Ostatnia aktualizacja: ".strftime('%d-%m-%Y %H:%M:%S',localtime(time))."\n\n".$dataNew;
        close UCHWYT;
        #system("chown root:root $pathFile 1> /dev/null 2> /dev/null");
           if($runCommend) { system($runCommend); }
       }
 
       if($pathFileZone) {
        my $zoneNew = "\$TTL    7200\n";
           $zoneNew .= "@       IN      SOA     localhost. root.localhost. (\n";
           $zoneNew .= "                              1         ; Serial\n";
           $zoneNew .= "                         604800         ; Refresh\n";
           $zoneNew .= "                          86400         ; Retry\n";
           $zoneNew .= "                        2419200         ; Expire\n";
           $zoneNew .= "                         604800 )       ; Negative Cache TTL\n";
           $zoneNew .= "@       IN      NS      localhost.\n";
           $zoneNew .= "@       IN      A       $addressIP\n";
 
        my $zoneOld = "";
           if(-e $pathFileZone) {
            open(UCHWYT, $pathFileZone);
              while (my $row = <UCHWYT>) { if(!($row =~ /^##\sOstatnia\saktualizacja/)) { $zoneOld .= $row; } }
            close (UCHWYT);
            $zoneOld =~ s/^\s+//;
            $zoneOld =~ s/\s+$//;
           }
 
           if($zoneOld ne $zoneNew) {
            open(UCHWYT, '>', $pathFileZone) or die "Nie można otworzyć $pathFileZone: $!"; 
            print UCHWYT $zoneNew;
            close UCHWYT;
            #system("chown root:root $pathFileZone 1> /dev/null 2> /dev/null");
           }
       }
 
  # } else {
 #   print STDERR "Error: ".$response->status_line."\n";
 #  }
