#!/usr/bin/perl

use English;
use warnings;
use FindBin;
use IO::File;
use Path::Class;
use Test::Most 'no_plan';
use lib (Path::Class::Dir->new($FindBin::Bin,'..','lib')->resolve->stringify);
use NotifiableTestObj;

BEGIN {
   use_ok('NotifiableTestObj');
}

{
    my $obj = testNewNotifiableTestObj();
    testWoutLogging($obj);
    testWithLogging($obj);
}

sub testNewNotifiableTestObj {
   my $notifiable = new_ok('NotifiableTestObj' => [], 'Test new notifiable object');

   can_ok($notifiable,qw/logger loggerCategory echo warning exception/);
   return($notifiable);
}

sub testWoutLogging {
   my ($obj) = @_;
   
   #test echo
   SKIP: {
      my $ORIG_STDOUT = *STDOUT;
      open(my $strFH, '>', \(my $stdout));
      skip 'Failed to redirect STDOUT to String',2 if (!$strFH);
      *STDOUT = $strFH;
      select(STDOUT);
      lives_ok {$obj->echo('echo message')} 'message echoed';
      *STDOUT = $ORIG_STDOUT;
      select(STDOUT); #ensure that default for print is back to STDOUT.
      close($strFH);
      like($stdout,qr/echo message/, 'original message echoed to STDOUT');
   }
   
   #test warning
   warning_like {$obj->warning('warning message')} qr/warning message/, 'warning message thrown';
   
   #test exception
   throws_ok {$obj->exception('error message')} qr/error message/, 'exception thrown';
}

sub testWithLogging {
   my ($obj) = @_;
 
   #Initialise logger
   Log::Log4perl::init(Path::Class::Dir->new($FindBin::Bin,'notify_logging.cfg')->stringify);
   
   #test echo - default INFO level message
   $obj->echo('echo message');
   die_on_fail;
   my $logf = _openLogFile();
   my $logged = _readLog($logf);
   like($logged,qr/INFO\] echo message/, 'echo message logged');
   restore_fail;
   
   #test echo - warning level message
   $obj->echo('echo warning level message','warn');
   $logged = _readLog($logf);
   like($logged,qr/WARN\] echo warning level message/, 'echo warning level message logged');
   
   #test warning - default WARN level message
   warning_like {$obj->warning('warning message logged')} qr/warning message logged/, 'warning message thrown';
   $logged = _readLog($logf);
   like($logged,qr/WARN\] warning message logged/, 'warning message also logged');
   
   #test warning - INFO level message
   warning_like {$obj->warning('warning info level logged','info')} qr/warning info level logged/, 'warning info level message thrown';
   $logged = _readLog($logf);
   like($logged,qr/INFO\] warning info level logged/, 'warning info level message also logged');
   
   #test exception - default FATAL level message
   throws_ok {$obj->exception('exception message logged')} qr/exception message logged/, 'exception message thrown';
   $logged = _readLog($logf);
   like($logged,qr/FATAL\] exception message logged/, 'exception message also logged');
   
   #test exception - ERROR level message
   throws_ok {$obj->exception('exception error level logged','error')} qr/exception error level logged/, 'exception error level message thrown';
   $logged = _readLog($logf);
   like($logged,qr/ERROR\] exception error level logged/, 'exception error level message also logged');
}

sub _openLogFile {
   my $lfh = IO::File->new;

   ok($lfh->open(Path::Class::Dir->new($FindBin::Bin,'notifiable.log'),'<'), 'Open log file for reading');
   return($lfh);
}

sub _readLog {
   my ($lfh) = @_;
   
   my @lines = $lfh->getlines;
   return(join('',@lines));
}