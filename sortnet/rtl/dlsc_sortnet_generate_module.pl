#!/usr/bin/perl

# 
# Copyright (c) 2011, Daniel Strother < http://danstrother.com/ >
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#   - Redistributions of source code must retain the above copyright notice,
#     this list of conditions and the following disclaimer.
#   - Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#   - The name of the author may not be used to endorse or promote products
#     derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
# EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
# TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

use Algorithm::Networksort qw(:all);

my $inputs = $ARGV[0];

if($inputs <= 1 || $inputs > 16)
{
    print "inputs out of bounds: 1 < inputs <= 16\n";
    exit;
}

my $algorithm = 'batcher';

my @network = nw_comparators($inputs, algorithm => $algorithm);
my @grouped_network = nw_group(\@network, $inputs, grouping=>'parallel');

my $comparators = scalar @network;
my $levels = scalar @grouped_network;

open(MODFILE, ">dlsc_sortnet_$inputs.v");

# module
print MODFILE <<ENDV;
// 
// Copyright (c) 2011, Daniel Strother < http://danstrother.com/ >
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//   - Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//   - Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer in the
//     documentation and/or other materials provided with the distribution.
//   - The name of the author may not be used to endorse or promote products
//     derived from this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED
// WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
// EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
// TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

// auto-generated by dlsc_sortnet_generate_module.pl
// using Perl Algorithm::Networksort
// algorithm:   $algorithm
// inputs:      $inputs
// levels:      $levels
// comparators: $comparators

module dlsc_sortnet_$inputs #(
    parameter META      = 1,        // width of bypassed metadata
    parameter DATA      = 16,       // width of data for each element
    parameter ID        = 1,        // width of IDs for each element
    parameter PIPELINE  = 0,
    // derived; don't touch
    parameter ID_I      = ($inputs*ID),
    parameter DATA_I    = ($inputs*DATA)
) (
    input   wire                    clk,
    input   wire                    rst,

    input   wire                    in_valid,       // qualifier
    input   wire    [META-1:0]      in_meta,        // metadata to be delay-matched to sorting operation
    input   wire    [DATA_I-1:0]    in_data,        // unsorted data
    input   wire    [ID_I-1:0]      in_id,          // identifiers for unsorted data

    output  wire                    out_valid,      // delayed qualifier
    output  wire    [META-1:0]      out_meta,       // delayed in_meta
    output  wire    [DATA_I-1:0]    out_data,       // sorted data
    output  wire    [ID_I-1:0]      out_id          // identifiers for sorted data
);

ENDV


my $lvl = 0;

# inputs

my $inputsm = $inputs-1;

print MODFILE <<ENDV;

// ** inputs **
wire    [ID-1:0]    lvl$lvl\_id [$inputsm:0];
wire    [DATA-1:0]  lvl$lvl\_data [$inputsm:0];
ENDV

for my $i (0 .. ($inputs-1))
{
print MODFILE <<ENDV;
assign lvl$lvl\_id[$i]   = in_id  [ ($i*  ID) +:   ID ];
assign lvl$lvl\_data[$i] = in_data[ ($i*DATA) +: DATA ];
ENDV
}

# levels
foreach my $group (@grouped_network)
{
    $lvlm = $lvl;
    $lvl++;
    $fmt = nw_format($group);

print MODFILE <<ENDV;


// ** level $lvl **
// $fmt

wire    [ID-1:0]    lvl$lvl\_id [$inputsm:0];
wire    [DATA-1:0]  lvl$lvl\_data [$inputsm:0];
ENDV

    @used = (0) x $inputs;

    # always pipeline last level
    my $pipeline = "PIPELINE";
    if($lvl == $levels)
    {
        $pipeline = "1";
    }

    foreach my $pairv (@{$group})
    {
        @pair = @{$pairv};

        $p0 = $pair[0];
        $p1 = $pair[1];

        $used[$p0] = 1;
        $used[$p1] = 1;

print MODFILE <<ENDV;

// level $lvl: compex($p0,$p1)
dlsc_compex #(
    .DATA       ( DATA ),
    .ID         ( ID ),
    .PIPELINE   ( $pipeline )
) dlsc_compex_inst_$lvl\_$p0\_$p1 (
    .clk        ( clk ),
    .in_id0     ( lvl$lvlm\_id[$p0] ),
    .in_data0   ( lvl$lvlm\_data[$p0] ),
    .in_id1     ( lvl$lvlm\_id[$p1] ),
    .in_data1   ( lvl$lvlm\_data[$p1] ),
    .out_id0    ( lvl$lvl\_id[$p0] ),
    .out_data0  ( lvl$lvl\_data[$p0] ),
    .out_id1    ( lvl$lvl\_id[$p1] ),
    .out_data1  ( lvl$lvl\_data[$p1] )
);
ENDV
    }

    for my $i(0 .. ($inputs-1))
    {
        next if $used[$i];
print MODFILE <<ENDV;

// level $lvl: pass-through $i
dlsc_pipedelay #(
    .DATA       ( DATA ),
    .DELAY      ( ($pipeline > 0) ? 2 : 1 )
) dlsc_pipedelay_inst_data_$lvl\_$i (
    .clk        ( clk ),
    .in_data    ( lvl$lvlm\_data[$i] ),
    .out_data   ( lvl$lvl\_data[$i] )
);
dlsc_pipedelay #(
    .DATA       ( ID ),
    .DELAY      ( ($pipeline > 0) ? 2 : 1 )
) dlsc_pipedelay_inst_id_$lvl\_$i (
    .clk        ( clk ),
    .in_data    ( lvl$lvlm\_id[$i] ),
    .out_data   ( lvl$lvl\_id[$i] )
);
ENDV
    }

}


# outputs

print MODFILE "\n\n// ** outputs **\n";

for my $i (0 .. ($inputs-1))
{
print MODFILE <<ENDV;
assign out_id  [ ($i*  ID) +:   ID ] = lvl$lvl\_id[$i];
assign out_data[ ($i*DATA) +: DATA ] = lvl$lvl\_data[$i];
ENDV
}

# valid/meta delayline

my $levelsm = $levels-1;
print MODFILE <<ENDV;


// ** delay valid/meta **
dlsc_pipedelay_valid #(
    .DATA       ( META ),
    .DELAY      ( $levelsm * (PIPELINE?2:1) + 2 ) // 1 or 2 cycles per intermediate stage; last stage always takes 2
) dlsc_pipedelay_valid_inst (
    .clk        ( clk ),
    .rst        ( rst ),
    .in_valid   ( in_valid ),
    .in_data    ( in_meta ),
    .out_valid  ( out_valid ),
    .out_data   ( out_meta )
);
ENDV


print MODFILE "\nendmodule\n\n";

close(MODFILE);

