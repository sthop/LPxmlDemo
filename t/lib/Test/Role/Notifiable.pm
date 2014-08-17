################################################################################
# Author: Sten Hopkins
################################################################################

package Test::Role::Notifiable;

use English;
use FindBin;
use Getopt::Long;
use Log::Log4perl qw/:easy/;
use Path::Class;
use Test::Class::Moose;
use Test::Files;
use Test::Moose::More;
use MooseX::Privacy;
use MooseX::Test::Role;
use Try::Tiny;
use lib (Path::Class::Dir->new($FindBin::Bin,'..','lib')->resolve->stringify);
use Args;
use Role::Notifiable;

with 'Role::Argv';

################################################################################
# Attributes:
################################################################################
has 'test_notifiable' => (isa => 'Object',
   is => 'rw',
   documentation => q/The class object for the Notifiable role being tested/
);

has _logFile => (isa => 'Path::Class::File',
   is => 'rw',
   default => sub {Path::Class::File->new($FindBin::Bin,'Data','notifiable_test.log')},
   documentation => q/The test log file. Must match the file defined in the logger config/
);

has _loggedMsgs => ( isa => 'Str',
   is => 'rw',
   default => '',
   documentation => q/Message to be logged so as to compare against what is actually logged/
);

################################################################################
# Public Method
# Automatically called at start of Testing the Notifiable Role
################################################################################
sub test_startup {
   my $test = shift;
   $test->next::method;

   #get an anonymous object that consumes Role::Notifiable
   my $notifiable = consuming_object('Role::Notifiable');
   $test->test_notifiable($notifiable);
}

################################################################################
# Public Method
# Automatically called before each test method
################################################################################
sub test_setup {
   my $test = shift;
   $test->next::method;

   #Store the command line arguments, so that we can test notifiable with our own command line arguments
   if ($test->test_report->current_method->name =~ /_verbose_/) {
      $test->alterArgv('-t' => 'dummy_taxonomy', '-d' => 'dummy_destination', '-p' => 'dummy_path', '-v' => 1);
      Args->initialize;
   }
   if ($test->test_report->current_method->name =~ /^test_03/ && !Log::Log4perl->initialized()) {
      #finished all the tests without logger. Now it's time to initialise a simple logger.
      try {
         Log::Log4perl->easy_init( {level => $INFO,
            file => '>'.$test->_logFile->stringify,
            layout => '[%d %p] %m%n'}
         );
      } catch {
         $test->test_skip('Failed to initialise logger: '.$_);
      };
   }
}

################################################################################
# Public Method
################################################################################
sub test_01_constructor {
   my $test = shift;
   
   my $notifObj = $test->test_notifiable;
   does_ok($notifObj, 'Role::Notifiable', 'does Role::Notifiable for logging using common method echo, warning, exception');
   has_attribute_ok($notifObj,'logger', 'Has a "logger" attribute');
   has_attribute_ok($notifObj,'loggerCategory','Has a "loggerCategory" attribute');
   has_method_ok($notifObj,'echo','warning','exception');
}

################################################################################
# Public Method
################################################################################
sub test_02_verbose_echo_without_logging {
   my $test = shift;
   my $notifObj = $test->test_notifiable;

   #test echo (verbose mode) by capturing stdout and redirecting to a string
   SKIP: {
      my $capturedMsg = $test->_capture_echo_message('echo message');
      like($capturedMsg,qr/echo message/, 'original message echoed to STDOUT');
   }
}

################################################################################
# Public Method
################################################################################
sub test_02_echo_without_logging {
   my $test = shift;

   #test echo by capturing stdout and redirecting to a string
   SKIP: {
      ok(!$test->_capture_echo_message('echo message'),
         'Message not echoed to STDOUT');
   }
}

################################################################################
# Public Method
################################################################################
sub test_02_warn_without_logging {
   my $test = shift;
   warning_like {$test->test_notifiable->warning('warning message')} qr/^WARNING! warning message\s*$/, 'warning thrown';
   warning_like {$test->test_notifiable->warning('error warning message','error')} qr/^ERROR! error warning message\s*$/, 'error warning thrown';
}

################################################################################
# Public Method
################################################################################
sub test_02_verbose_warn_without_logging {
   my $test = shift;
   warning_like {$test->test_notifiable->warning('warning message')} qr/^WARNING! warning message/, 'warning thrown (verbose mode)';
}

################################################################################
# Public Method
################################################################################
sub test_02_verbose_err_warning_without_logging {
   my $test = shift;
   warning_like {$test->test_notifiable->warning('error level warning message','error')} qr/^ERROR! error level warning message/, 'error level warning thrown (verbose mode)';
}

################################################################################
# Public Method
################################################################################
sub test_02_exception_without_logging {
   my $test = shift;
   throws_ok {$test->test_notifiable->exception('error message')} qr/^FATAL! error message\s*$/, 'exception thrown';
   throws_ok {$test->test_notifiable->exception('error message','error')} qr/^ERROR! error message\s*$/, 'error level exception thrown';
}

################################################################################
# Public Method
################################################################################
sub test_02_verbose_exception_without_logging {
   my $test = shift;
   throws_ok {$test->test_notifiable->exception('error message')} qr/^FATAL! error message.*(?:\n.+)+called at \//, 'fatal exception thrown (verbose mode)';
}

################################################################################
# Public Method
################################################################################
sub test_02_verbose_error_exception_without_logging {
   my $test = shift;
   throws_ok {$test->test_notifiable->exception('error message','error')} qr/^ERROR! error message.*(?:\n.+)+called at \//, 'error level exception thrown (verbose mode)';
}

################################################################################
# Public Method
################################################################################
sub test_03_verbose_echo_with_logging {
   my $test = shift;
   SKIP: {
      my $testMsg = 'log & echo message to STDOUT';
      my $captureMsg = $test->_capture_echo_message($testMsg);
      like($captureMsg,qr/$testMsg/, 'original message echoed to STDOUT');
      $test->_loggedMsgs($test->_loggedMsgs.'INFO] '.$testMsg."\n");
   }
}

################################################################################
# Public Method
################################################################################
sub test_03_echo_with_logging {
   my $test = shift;
   SKIP: {
      my $testMsg = 'log message only';
      ok(!$test->_capture_echo_message($testMsg),
            'Logging message but not echoed to STDOUT');
      $test->_loggedMsgs($test->_loggedMsgs.'INFO] '.$testMsg."\n");
      $testMsg = 'log warning level message only';
      ok(!$test->_capture_echo_message($testMsg,'warn'),
            'Logging warning level message but not echoed to STDOUT');
      $test->_loggedMsgs($test->_loggedMsgs.'WARN] '.$testMsg."\n");
      $testMsg = 'debug level message not echoed or logged';
      ok(!$test->_capture_echo_message($testMsg,'debug'),
            'debug message not logged or echoed to STDOUT');
   }
}

################################################################################
# Public Method
################################################################################
sub test_03_warn_with_logging {
   my $test = shift;

   my $testMsg = 'log warning message';
   warning_like {$test->test_notifiable->warning($testMsg)} qr/$testMsg/, 'warning message thrown';
   $test->_loggedMsgs($test->_loggedMsgs.'WARN] WARNING! '.$testMsg."\n");
   $testMsg = 'log error level warning message';
   warning_like {$test->test_notifiable->warning($testMsg,'error')} qr/$testMsg/, 'error level warning message thrown';
   $test->_loggedMsgs($test->_loggedMsgs.'ERROR] ERROR! '.$testMsg."\n");
}

################################################################################
# Public Method
################################################################################
sub test_03_exception_with_logging {
   my $test = shift;

   my $testMsg = 'log exception message';
   throws_ok {$test->test_notifiable->exception($testMsg)} qr/$testMsg/, 'exception thrown';
   $test->_loggedMsgs($test->_loggedMsgs.'FATAL] FATAL! '.$testMsg."\n");
   $testMsg = 'log error level exception message';
   throws_ok {$test->test_notifiable->exception($testMsg,'error')} qr/$testMsg/, 'error level exception thrown';
   $test->_loggedMsgs($test->_loggedMsgs.'ERROR] ERROR! '.$testMsg."\n");
}

################################################################################
# Public Method
################################################################################
sub test_03_verbose_warn_with_logging {
   my $test = shift;

   my $testMsg = 'log verbose warning message';
   warning_like {$test->test_notifiable->warning($testMsg)} qr/$testMsg/, 'verbose warning message thrown';
   $test->_loggedMsgs($test->_loggedMsgs.'WARN] WARNING! '.$testMsg." at \n");
   $testMsg = 'log verbose error level warning message';
   warning_like {$test->test_notifiable->warning($testMsg,'error')} qr/$testMsg/, 'verbose error level warning message thrown';
   $test->_loggedMsgs($test->_loggedMsgs.'WARN] ERROR! '.$testMsg." at \n");
}

################################################################################
# Public Method
################################################################################
sub test_03_verbose_exception_with_logging {
   my $test = shift;

   my $testMsg = 'log verbose exception message';
   throws_ok {$test->test_notifiable->exception($testMsg)} qr/$testMsg/, 'exception thrown';
   $test->_loggedMsgs($test->_loggedMsgs.'FATAL] FATAL! '.$testMsg." at \n");
   $testMsg = 'log verbose error level exception message';
   throws_ok {$test->test_notifiable->exception($testMsg,'error')} qr/$testMsg/, 'error level exception thrown';
   $test->_loggedMsgs($test->_loggedMsgs.'FATAL] ERROR! '.$testMsg." at \n");
}

################################################################################
# Public Method
################################################################################
sub test_04_log_file_captured_all_logging_correctly {
   my $test = shift;
   file_filter_ok($test->_logFile, $test->_loggedMsgs,
      \&_stripUnwantedFileContent,'Log file contains messages as expected');
}

################################################################################
# Public Method
# Automatically called after every test method
################################################################################
sub test_teardown {
   my $test = shift;
   $test->next::method;

   if ($test->test_report->current_method->name =~ /_verbose_/) {
      #restore the original command line arguments
      $test->restoreArgv();
      Args->clear;
   }
}

################################################################################
# Public Method
# Called at the end of testing the Notifiable Role
################################################################################
sub test_shutdown {
   my $test = shift;
   $test->next::method;

   #delete the test log file if it exists (don't want to leave it hanging around)
   unlink($test->_logFile->stringify) if (-e $test->_logFile);
}

################################################################################
# Private Method _capture_echo_message
# Setting up a Handle to redirect STDOUT to a string
################################################################################
private_method _capture_echo_message => sub {
#sub _capture_echo_message {
   my $test = shift;
   my ($message,$lvl) = @_;
   
   my $notifObj = $test->test_notifiable;
   my $ORIG_STDOUT = *STDOUT;
   open(my $strFH, '>', \(my $stdout));
   skip 'Failed to redirect STDOUT to String' if (!$strFH);
   *STDOUT = $strFH;
   select(STDOUT);
   my @params = ($message);
   push(@params,$lvl) if (defined $lvl);
   lives_ok {$notifObj->echo(@params)} 'message echoed';
   *STDOUT = $ORIG_STDOUT;
   select(STDOUT); #ensure that default for print is back to STDOUT.
   close($strFH);
   return($stdout);
};

################################################################################
# Private Method _stripUnwantedFileContent
# Used by Test::Files to filter out differences in content that don't need to be
# tested.
################################################################################
sub _stripUnwantedFileContent {
   my $line = shift;
   
   #Log messages will start with date & time stamp. Don't need to validate this, so strip it off
   return if ($line =~ /^.+?\s\w+]\s\t/);
   $line =~ s/^.+?\s(\w+])/$1/;
   $line =~ s/( at )\/.+ line \d+\./$1/;
   return($line);
}

__PACKAGE__->meta->make_immutable;
no Moose;

################################################################################
1;