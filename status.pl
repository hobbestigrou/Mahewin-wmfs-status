#!/usr/bin/perl

use strict;
use warnings;
use Sys::Statistics::Linux;
use Sys::Statistics::Linux::DiskUsage;

sub _my_home {
    if ( exists $ENV{HOME} && defined $ENV{HOME} ) {
        return $ENV{HOME};
    }

    if ( $ENV{LOGDIR} ) {
        return $ENV{LOGDIR};
    }

    return undef;
}

sub free {
    my $lxs = Sys::Statistics::Linux->new(
        memstats  => 1,
    );
    my $stat = $lxs->get;
    my $free = 'Mem: ' . int($stat->memstats->{memfree} / 1024) . '/' . int($stat->memstats->{memused} / 1024);

    return $free;
}

sub disk_space {
    my $disk_usage = Sys::Statistics::Linux::DiskUsage->new(
        cmd => {
            # This is the default
            df   => 'df -hP 2>/dev/null',
        }
    );
    my $stat = $disk_usage->get;
    my $disk = 'Disk: ' . $stat->{'/dev/sda6'}->{usage} . '/' . $stat->{'/dev/sda6'}->{free};

    return $disk;

}

sub time_date {
    my $lxs = Sys::Statistics::Linux->new();

    $lxs->settime('%Y/%m/%d %H:%M:%S');
    my $date_time = 'Date: ' . $lxs->gettime;

    return $date_time;
}

my $free      = free();
my $disk      = disk_space();
my $time_date = time_date();

`wmfs -s "$free $disk $time_date"`;
