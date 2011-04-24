#!/usr/bin/perl

use strict;
use warnings;
use Sys::Statistics::Linux;
use Sys::Statistics::Linux::DiskUsage;
use Config::IniFiles;

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

    my $stat     = $lxs->get;
    my $memfree  = $stat->memstats->{memfree};
    my $memused  = $stat->memstats->{memused};
    my $memtotal = $stat->memstats->{memtotal};

    my $home = _my_home();
    my $cfg  = Config::IniFiles->new(
        -file => "$home/.config/wmfs/mahewin-wmfs-statusrc"
    );

    my $format = $cfg->val('memory', 'format') || 'string';
    my $free   = 'Mem: ' . int($memfree / 1024) . '/' . int($memused / 1024);

    if ( $format eq 'percent' ) {
        my $free_usage = sprintf("%0.2f", int($memused / 1024) / int($memtotal / 1024 ) * 100);
        $free = 'Mem: ' . $free_usage . '%';
    }

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
    my $home = _my_home();
    my $cfg  = Config::IniFiles->new(
        -file => "$home/.config/wmfs/mahewin-wmfs-statusrc"
    );

    my $format    = $cfg->val('disk', 'format') || 'string';
    my $disk_path = $cfg->val('disk', 'disk_path') || '/dev/sda1';
    my $disk      = 'Disk: ' . $stat->{$disk_path}->{usage} . '/' . $stat->{$disk_path}->{free};

    if ( $format eq 'percent' ) {
        my @usage = split(/G/, $stat->{$disk_path}->{usage});
        my @total = split(/G/, $stat->{$disk_path}->{total});
        $usage[0] =~ s/,/./;

        my $disk_usage = sprintf("%0.2f", $usage[0] / $total[0] * 100);
        $disk = 'Disk: ' . $disk_usage . '%';
    }

    return $disk;
}

sub time_date {
    my $lxs  = Sys::Statistics::Linux->new();
    my $home = _my_home();
    my $cfg  = Config::IniFiles->new(
        -file => "$home/.config/wmfs/mahewin-wmfs-statusrc"
    );
    my $format = $cfg->val('date', 'format') || '%Y/%m/%d %H:%M:%S';

    $lxs->settime($format);
    my $date_time = 'Date: ' . $lxs->gettime;

    return $date_time;
}

sub status {
    my $home = _my_home();
    my $cfg  = Config::IniFiles->new(
        -file => "$home/.config/wmfs/mahewin-wmfs-statusrc"
    );

    my $free      = free()       if $cfg->val('memory', 'display');
    my $disk      = disk_space() if $cfg->val('disk', 'display');
    my $time_date = time_date()  if $cfg->val('date', 'display');

    `wmfs -s "$free $disk $time_date"`;
}

status();
