# Module OMS

package OMS;

use strict;
use warnings;
use Encode;
use YAML::Tiny;
use Data::Dumper;
use Carp qw(croak);
use XBase 'version' => 3;
use DBI;
#use Text::Iconv;

#$converter = Text::Iconv->new("CP1251", "CP866");
#$converted = $converter->convert("Text to convert");


our $VERSION = '0.01';


sub new {
    my ($class, $args) = @_;
    my $self = {
        config    => $args->{config}  || 'OMS.yml',
		pathOMS   => $args->{pathOMS} || '/home/stas/OMS',
        pathTPL   => $args->{pathTPL} || 'tpl',
		pathOUT   => $args->{pathOUT} || 'out',
		authid    => $args->{authid}  || 'statist/avmqlg26',
		oraclesrv => $args->{connid}  || 'kasustat',
		year      => $args->{year},
		month     => $args->{month},
        is_file   => $args->{is_file} || 0 # if 0 - rename file. if 1 - delete file
    };

    bless $self, $class;

	return $self;
}

sub alltrim {
	my $str = shift;

	$str =~ s/^\s+|\s+$//;

}

sub LPad {
	my ($str, $len, $chr) = @_;
	$chr = " " unless (defined($chr));
	return "" unless (defined($str));
	return substr(($chr x $len) . $str, -1 * $len, $len);

} # LPad

sub proper {
	#my $self = shift;
	my ($str,$x) = @_;

    #return encode('windows-1251',ucfirst(lc(decode('windows-1251',$str))));
    return encode('cp866',ucfirst(lc(decode('cp866',$str))));
}

sub space {
	#my $self = shift;
	my ($l,$chr) = @_;
	$chr = ' ';
	return ($chr x $l);
}


sub RPad {
	my ($str, $len, $chr) = @_;
	$chr = " " unless (defined($chr));
	return substr($str . ($chr x $len), 0, $len);
} # RPad


sub createDBF  {
	my $self = shift;
    my ($year, $month, $t) = @_;
    my ($nowday,$nowmonth,$nowyear,$nowhour,$nowminute)=(localtime)[3,4,5,2,1];
    $nowyear+=1900;
    $nowmonth += 1;

	croak "Illegal parameter list of number of values"
        if @_ != 3;

    my $filename = $self->{pathOMS}.'/'.$self->{pathOUT}.'/'.$t.$month.substr($year,3,1).".dbf";

    unlink $filename if (-e $filename)  && ($self->{is_file} == 1);
    rename $filename, $filename.".$nowyear".LPad($nowmonth,2,'0')."$nowday$nowhour$nowminute"
                                    if ( -e $filename ) && ($self->{is_file} == 0);

	my ( $tplname, $yaml, @docw, $k, $i, @tpl_struct, $crStr, $insStr );

    #print $self->{pathOMS}.'/'.$self->{pathTPL}.'/'.$self->{config};

	$yaml = YAML::Tiny->read($self->{pathOMS}.'/'.$self->{pathTPL}.'/'.$self->{config});

    $tplname = 'tpl'.$t;

	@docw = $yaml->[0]->{$tplname};

    #print Dumper(@_);

	foreach $k ( keys @docw ) {
		foreach $i ( keys $docw[$k] ) {
			#print "Field #$docw[$k]->{$i}->{'id'}: $i is type: ".$docw[$k]->{$i}->{'type'};
			#print " and width is ".$docw[$k]->{$i}->{'width'} if $docw[$k]->{$i}->{'width'} ne "null";
			#print " and also decimal is ".$docw[$k]->{$i}->{'decimal'} if $docw[$k]->{$i}->{'decimal'} ne "null";
			#print "\n";

			$tpl_struct[$docw[$k]->{$i}->{id}] = {
				name => $i,
				type => $docw[$k]->{$i}->{type},
				width => $docw[$k]->{$i}->{width},
				decimal => $docw[$k]->{$i}->{decimal}
			};

		}
	}

	$crStr = "create table $t".$month.substr($year,3,1)." (";
	foreach $k ( keys @tpl_struct )
	{
		my $s = $tpl_struct[$k]->{name} if defined $tpl_struct[$k]->{name};
		   $s = "" unless defined $tpl_struct[$k]->{name};
		if ( $s ne "" )
		{
			$crStr .=  "$tpl_struct[$k]->{name} $tpl_struct[$k]->{type}";
			$crStr .= "($tpl_struct[$k]->{width}" if lc($tpl_struct[$k]->{type}) ne "date";
			$crStr .= ",$tpl_struct[$k]->{decimal}" if lc($tpl_struct[$k]->{decimal}) ne "null";
			$crStr .= ")" if lc($tpl_struct[$k]->{type}) ne "date";
			$crStr .= ", " if $#tpl_struct != $k;
		}
	}
	$crStr .= ");";

	my $dbh = DBI->connect("DBI:XBase:".$self->{pathOMS}.'/'.$self->{pathOUT}.'/')
        or die $DBI::errstr;
	my $sth = $dbh->prepare($crStr) or die $dbh-errstr();
	$sth->execute() or die $sth->errstr();
	return $dbh;
}

sub get_ins_string {
	my $self = shift;
    my ($year, $month, $t) = @_;

	my ( $tplname, $yaml, @docw, $k, $i, $acc, @tpl_struct, $crStr, $insStr );

	$yaml = YAML::Tiny->read($self->{pathOMS}.'/'.$self->{pathTPL}.'/'.$self->{config});

    $tplname = 'tpl'.$t;

	@docw = $yaml->[0]->{$tplname};

    #print Dumper(@docw);

	foreach $k ( keys @docw ) {
		foreach $i ( keys $docw[$k] ) {
			$tpl_struct[$docw[$k]->{$i}->{id}] = {
				name => $i,
				type => $docw[$k]->{$i}->{type},
				width => $docw[$k]->{$i}->{width},
				decimal => $docw[$k]->{$i}->{decimal}
			};

		}
	}

	$insStr = "insert into $t".$month.substr($year,3,1)." (";
	#$insStr = "insert into $t (" unless ($t eq "SSP4708");

	foreach $k ( keys @tpl_struct )
	{
		my $s = $tpl_struct[$k]->{name} if defined $tpl_struct[$k]->{name};
		   $s = "" unless defined $tpl_struct[$k]->{name};
		if ( $s  ne "" )
		{
			$insStr .= $tpl_struct[$k]->{name};
			$insStr .= ", " if $#tpl_struct != $k;
		}
	}
	$insStr .= ") values (";
	for($k = 1; $k<=$#tpl_struct; $k++) {
		$insStr .= "?";
		$insStr .= "," if $#tpl_struct != $k;
	}
	$insStr .= ")";

	return $insStr;

}

sub connect_to_oracle
{
	my $self = shift;

	my $dbh = DBI->connect("dbi:Oracle:$self->{oraclesrv}", $self->{authid}, '')
        or die $DBI::errstr;

#	$dbh->disconnect;
	return $dbh;
}

sub export_to_dbf
{
	my $self = shift;
    my ($t) = @_;

	my $cmd = "";
    my ($year, $month) = ($self->{year},$self->{month});

	if (uc($t) eq "SSP4708") {
		$cmd = $self->get_cmd_for_oms($year, $month);
		$self->doExpSSP4708($cmd, $self->get_ins_string($year,$month,$t),$year,$month,$t);
	} elsif (uc($t) eq "BRSP") {
		$cmd = $self->get_cmd_for_brsp($year, $month);
		$self->doExpBRSP($cmd, $self->get_ins_string($year,$month,$t),$year,$month,$t);
	} elsif (uc($t) eq "STASMP") {
	    $cmd = $self->get_cmd_for_stasmp;
		$self->doExpSTASMP($cmd, $self->get_ins_string($year,$month,$t),$year,$month,$t);
	} elsif (uc($t) eq "RES_SP") {
		$cmd = $self->get_cmd_for_res_sp;
		$self->doExpNciRes($cmd, $self->get_ins_string($year,$month,$t),$year,$month,$t);
	} elsif (uc($t) eq "NCIVIDU") {
		$cmd = $self->get_cmd_for_ncivid_u;
		$self->doExpNciVidU($cmd, $self->get_ins_string($year,$month,$t),$year,$month,$t);
	} elsif (uc($t) eq "SEGMENTS") {
		$cmd = $self->get_cmd_for_segments;
		$self->doExpStreets($cmd, $self->get_ins_string($year,$month,$t),$year,$month,$t);
	} elsif (uc($t) eq "STREETS") {
		$cmd = $self->get_cmd_for_streets;
		$self->doExpStreets($cmd, $self->get_ins_string($year,$month,$t),$year,$month,$t);
	} else {
		print "Parameter not in list {SSP4708, BRSP, STASMP, RES_SP, NCIVIDU, SEGMENTS, STREETS}\n";
		return;
	}
}

sub get_cmd_for_oms {
	my $self = shift;
	my ($year, $month) = @_;
	my $lcPeriod = $year.$month;
	my $cmd =
		"select
 RECID,
 PERIOD,
 SP_ID,
 PST,
 C_BR,
 PROFBR,
 D_U,
 T_UZ,
 T_UP,
 N_U,
 VID_U,
 COD,
 TAR,
 RES,
 DS,
 TRIM(DECODE(instr(TRIM(FAM), ' '), 0, TRIM(FAM), SUBSTR(TRIM(FAM),1, instr(TRIM(FAM), ' ')))) fam,
 DECODE(instr(TRIM(IM), ' '), 0, TRIM(IM), SUBSTR(TRIM(IM),1, instr(TRIM(IM), ' '))) im,
 DECODE(instr(TRIM(OT), ' '), 0, TRIM(OT), SUBSTR(TRIM(OT),1, instr(TRIM(OT), ' '))) ot,
 W,
 DR,
 SN_POL,
 TIP,
 QQ,
 C_OKATO,
 TO_NUMBER(NVL(V_DOC,0)) V_DOC,
 S_DOC,
 N_DOC,
 XX,
 LPU_ID
 from omstable2
 where  PERIOD = '$lcPeriod' and n_u not in (select a010 from s1)
-- and rownum < 100
";

}

sub get_cmd_for_brsp {
	my $self = shift;
	my ($year, $month) = @_;

	my $lcStartDate = "01.".$month.".".$year." 00:00";
	if (scalar($month)+1 > 12) {
		$year += 1;
		$month = "01";
	} else {
		$month += 1;
	}

	my $lcEndDate = "01.".LPad($month,2,'0').".".$year." 00:00";


	my $cmd = "
select
 substr(OMC_get_no_nbr_03_09_2014(e090, e130, ABS(NVL(f130,0)), g070, g060), 1, 10) C_BR,
 e090 PST,
 substr(OMC_get_nbr_text_03_09_2014(e090, e130, ABS(NVL(f130,0)), g070, g060), 1, 250) NAME
from
  karta_all_for_statist
  left outer join TarifsTables on cod = OMC_get_nbr_03_09_2014(e090, e130, ABS(NVL(f130,0)), g070, g060)
  left outer join MKB10Table on h030 = MKB10Table.code
where
 d050 between to_date('$lcStartDate', 'dd.mm.yyyy hh24:mi') and
               to_date('$lcEndDate', 'dd.mm.yyyy hh24:mi') and
-- поправили
 (case when( (e120 <21 or ((e120>20) and  (nvl(e080, 0) < 20))  or e120 is null)
     and --, 21, 22, 24
         (((get_nbr_dnevnik_03_09_2014(e090,e130) >= 1 )   and
         ((get_nbr_dnevnik_03_09_2014(e090, e130) <= 98 )))
         or
         (((get_nbr_dnevnik_03_09_2014(e090,e130) >= 100 ) and
         ((get_nbr_dnevnik_03_09_2014(e090, e130) <= 1000 )))))
     and
     get_nbr_dnevnik_03_09_2014(e090,e130) not between 300 and 320
     and
     (E090 < 1000 and E090 not in (67, 69, 71)) and
      E030 in (70, 71, 28, 99) and
     (coalesce(f070, f090, f240) is not null)
     ) then 1 else 0 end) = 1

/*
  check_br_task_all_03_09_2014(e090,
	e130,
    e120,
	e030,
    f070,
	f090,
    f240,
	e080) = 1
*/
group by
substr(OMC_get_no_nbr_03_09_2014(e090, e130, ABS(NVL(f130,0)), g070, g060), 1, 10),
  e090, substr(OMC_get_nbr_text_03_09_2014(e090, e130, ABS(NVL(f130,0)), g070, g060), 1, 250)
";

}

sub get_cmd_for_stasmp {
	my $self = shift;

	my $cmd = "
select
 to_char(code) as PST,
 text as NAME
from
 ncidict
where
 type = 32 and
 code between 1 and 57
union all
select
 to_char(posts_num) as PST,
 posts_comment as NAME
from
 kasu.posts
where
posts_num <> 77
union all
select
to_char(64) as PST,
'64-й пост' as NAME
from
dual
union all
select
to_char(45) as PST,
'45-ая подстанция' as NAME
from
dual
 union all
select
 to_char(68) as PST,
 'Доктор 03' as NAME
from
 dual
 union all
select
 to_char(76) as PST,
 'Поликлиника №1 по управления делами президента' as NAME
from
 dual
 union all
select
 to_char(70) as PST,
 'ОАО Медицина' as NAME
from
 dual";

	Encode::_utf8_off($cmd);
	Encode::from_to($cmd, 'utf-8', 'windows-1251');

	return $cmd;


}

sub get_cmd_for_res_sp{
	my $self = shift;
 my $cmd = "
select
 to_char(code) as res,
  SUBSTR(text,1,60) as Name
 from
  ncidict
 where
  type = 15 and
  code < 34
 order by code
";

}

sub get_cmd_for_ncivid_u {
	my $self = shift;
	my $cmd = "
select
  to_char(code) as vid_u,
  SUBSTR(text,1,60) as text
 from
  ncidict
 where
  type = 19
 order by code
";

}

sub get_cmd_for_segments {
	my $self = shift;
	my $cmd = "
SELECT
 strcode,
 numbeg,
 numend,
 numflag,
 region,
 podst,
 ps_add,
 segment_id,
 ruvd_code,
 zags,
 sobes,
 fire_ps,
 hospital,
 ps_add1,
 ps_add2,
 ps_add3,
 activity
 from
 kasu.segments";

}

sub get_cmd_for_streets {
	my $self = shift;
	my $cmd = "
SELECT
  strcode,
  NVL(strname,''),
  NVL(realname,''),
  NVL(strstat,0),
  NVL(state,''),
  NVL(oper,''),
  NVL(nmstreet,''),
  NVL(kod_fo,0),
  NVL(typ_u,0),
  to_char(NVL(dat_ul,to_date('01.01.1900','dd.mm.yyyy')),'YYYYMMDD') as dat_ul,
  NVL(kod_te,''),
  NVL(nmstreet_o,''),
  NVL(typ_r,''),
  NVL(dat_old,''),
  NVL(sort,''),
  NVL(dop_sort,''),
  NVL(activity,0)
from
kasu.streets
order by strcode";

}

sub doExpSSP4708 {
	my $self = shift;
	my ($cmd, $ins, $year, $month, $t) = @_;

	my ( $connDBF, $connORA, $sthDBF, @row,
		 $lc_d050,
		 $lc_recid,
		 $lc_period,
		 $lc_sp_id,
		 $lc_pst,
		 $lc_c_br,
		 $lc_profbr,
		 $lc_d_u,
		 $lc_t_uz,
		 $lc_t_up,
		 $lc_n_u,
		 $lc_vid_u,
		 $lc_cod,
		 $lc_tar,
		 $lc_res,
		 $lc_ds,
		 $lc_fam,
		 $lc_im,
		 $lc_ot,
		 $lc_w,
		 $lc_dr,
		 $lc_sn_pol,
		 $lc_tip,
		 $lc_qq,
		 $lc_c_okato,
		 $lc_v_doc,
		 $lc_s_doc,
		 $lc_n_doc,
		 $lc_xx,
		 $lc_lpu_id
		);

# Step #1 -> create dbf
	$connDBF = $self->createDBF($year, $month, $t);
	$sthDBF = $connDBF->prepare($ins) or die $connDBF->errstr;


	$connORA = $self->connect_to_oracle;
    my $sth  = $connORA->prepare($cmd) or die $connORA->errstr;
	$sth->execute() or die $sth->errstr;

	while((@row = $sth->fetchrow_array)) {

		$lc_d050 = $row[6];

		$lc_recid = $row[0];
		$lc_recid =~ s/^\s+|\s+$//g if defined $lc_recid;
		if ( length($lc_recid) == 0 ) {
			$lc_recid = space(7);
		} else {
			$lc_recid = substr($row[0],0,7);
		}

		$lc_period = $row[1];
		$lc_period =~ s/^\s+|\s+$//g;
		if ( $lc_period eq "") {
			$lc_period = space(6);
		} else {
			$lc_period = substr($lc_period,0,6);
		}

		$lc_sp_id = $row[2];
		$lc_pst = $row[3];
		$lc_pst =~ s/^\s+|\s+$//g;
		$lc_pst = substr( $lc_pst, 0, 3 );

		$lc_c_br = $row[4];
		$lc_c_br =~ s/^\s+|\s+$//g;
		if ( length($lc_c_br) == 0 ) {
			$lc_c_br = space(10);
		} else {
			$lc_c_br = substr( $lc_c_br, 0, 10 );
		}

		$lc_profbr = $row[5];
		$lc_profbr =~ s/^\s+|\s+$//g if defined $lc_profbr;
		$lc_profbr = "" unless defined $lc_profbr;
		if ( $lc_profbr eq "" ) {
			$lc_profbr = space(3);
		} else {
			$lc_profbr = substr( $lc_profbr, 0, 3 );
		}
		# date format for XBase -> 'YYYYMMDD'
		if ( $lc_d050 eq "" ) {
			$lc_d_u = "19900101";
		} else {
			$lc_d_u = substr( $lc_d050, 0, 4 ).substr( $lc_d050, 4, 2 ).substr( $lc_d050, 6, 2 );
		}

		#####
		$lc_t_uz = $row[7];
		$lc_t_uz =~ s/^\s+|\s+$//g;
		if ( $lc_t_uz eq "") {
			$lc_t_uz = space(5);
		} else {
			$lc_t_uz = substr( $lc_t_uz, 0, 5 );
		}

		$lc_t_up = defined($row[8]) ? $row[8] : space(5);
		$lc_t_up =~ s/^\s+|\s+$//g if defined $lc_t_up;
		$lc_t_up = "" unless defined $lc_t_up;
		if ( $lc_t_up eq "") {
			$lc_t_up = space(5);
		} else {
			$lc_t_up = substr( $lc_t_up, 0, 5 );
		}

		$lc_n_u = $row[9];
		$lc_n_u =~ s/^\s+|\s+$//g;
		if ( $lc_n_u eq "") {
			$lc_n_u = space(12);
		} else {
			$lc_n_u = substr( $lc_n_u, 0, 12 );
		}
		$lc_vid_u = defined($row[10]) ? $row[10] : space(6);
		$lc_vid_u =~ s/^\s+|\s+$//g;
		if ( $lc_vid_u eq "") {
			$lc_vid_u = space(6);
		} else {
			$lc_vid_u = substr( $lc_vid_u, 0, 6 );
		}

		if ( $row[11] eq "" || scalar($row[11]) == 0 ) { $lc_cod = 0; } else { $lc_cod = scalar($row[11]); }
		if ( $row[12] eq "" || scalar($row[12]) == 0 ) { $lc_tar = 0; } else { $lc_tar = scalar($row[12]); }

		if ( $row[13] eq "" || scalar($row[13]) == 0) { $lc_res = 0;} else { $lc_res = scalar($row[13]); }

		$lc_ds = $row[14];
		$lc_ds =~ s/^\s+|\s+$//g if defined $lc_ds;
		$lc_ds = "" unless defined $lc_ds;
		if ( $lc_ds eq "") {
			$lc_ds = space(6);
		} else {
			$lc_ds = substr( $lc_ds, 0, 6 );
		}

		$lc_fam = $row[15];
		$lc_fam =~ s/^\s+|\s+$//g;
		if ( $lc_fam eq "") {
			$lc_fam = space(25);
		} else {
			$lc_fam = proper(substr( $lc_fam, 0, 25 ));
		}

		$lc_im = $row[16];
		$lc_im =~ s/^\s+|\s+$//g;
		if ( $lc_im eq "") {
			$lc_im = space(20);
		} else {
			$lc_im = proper(substr( $lc_im, 0, 20 ));
		}

		$lc_ot = $row[17];
		$lc_ot =~ s/^\s+|\s+$//g if defined $lc_ot;
		$lc_ot = "" unless defined $lc_ot;
		if ( $lc_ot eq "") {
			$lc_ot = space(20);
		} else {
			$lc_ot = proper(substr( $lc_ot, 0, 20 ));
		}

		if ( $row[18] eq "" || scalar($row[18]) == 0) { $lc_w = 0; } else { $lc_w = scalar($row[18]); }

		$lc_dr = $row[19];
		$lc_dr =~ s/^\s+|\s+$//g;
		if ( $lc_dr  eq "" ) {
			$lc_dr = "19900101";
		} else {
			$lc_dr = substr( $lc_dr, 0, 4 ).substr( $lc_dr, 5, 2 ).substr( $lc_dr, 8, 2 );
		}

		$lc_sn_pol = $row[20];
		$lc_sn_pol =~ s/^\s+|\s+$//g if defined $lc_sn_pol;
		$lc_sn_pol = "" unless defined $lc_sn_pol;
		if ( $lc_sn_pol eq "") {
			$lc_sn_pol = space(25);
		} else {
			$lc_sn_pol = substr( $lc_sn_pol, 0, 25 );
		}

		$lc_tip = $row[21];
		$lc_tip =~ s/^\s+|\s+$//g if defined $lc_tip;
		$lc_tip = "" unless defined $lc_tip;
		if ( $lc_tip eq "" ) {
			$lc_tip = space(1);
		} else {
			$lc_tip = substr( $lc_tip, 0, 1 );
		}
		$lc_qq = $row[22];
		$lc_qq =~ s/^\s+|\s+$//g if defined $lc_qq;
		$lc_qq = "" unless defined $lc_qq;
		if ( $lc_qq eq "" ) {
			$lc_qq = space(2);
		} else {
			$lc_qq = substr( $lc_qq, 0, 2 );
		}
		$lc_c_okato = $row[23];
		$lc_c_okato =~ s/^\s+|\s+$//g if defined $lc_c_okato;
		$lc_c_okato = "" unless defined $lc_c_okato;
		if ( $lc_c_okato eq "" ) {
			$lc_c_okato = space(5);
		} else {
			$lc_c_okato = substr( $lc_c_okato, 0, 5 );
		}

		if ( $row[24] eq "" || scalar($row[24]) == 0) { $lc_v_doc = 0; } else { $lc_v_doc = scalar($row[24]); }

		$lc_s_doc = $row[25];
		$lc_s_doc =~ s/^\s+|\s+$//g if defined $lc_s_doc;
		$lc_s_doc = "" unless defined $lc_s_doc;
		if ( $lc_s_doc eq "") {
			$lc_s_doc = space(9);
		} else {
			$lc_s_doc = substr( $lc_s_doc, 0, 9 );
		}
		$lc_n_doc = $row[26];
		$lc_n_doc =~ s/^\s+|\s+$//g if defined $lc_n_doc;
		$lc_n_doc = "" unless defined $lc_n_doc;
		if ( $lc_n_doc eq "") {
			$lc_n_doc = space(8);
		} else {
			$lc_n_doc = substr( $lc_n_doc, 0, 8 );
		}
		$lc_xx = $row[27];
		$lc_xx =~ s/^\s+|\s+$//g if defined $lc_xx;
		$lc_xx = "" unless defined $lc_xx;
		if ( $lc_xx eq "" ) {
			$lc_xx = space(40);
		} else {
			$lc_xx = substr( $lc_xx, 1, 40 );
		}
		$lc_lpu_id = 0 unless defined $lc_lpu_id;
		$lc_lpu_id = scalar($row[28]) if defined $lc_lpu_id;
		#if ( $lc_lpu_id eq "") { $lc_lpu_id = 0; } else { $lc_lpu_id = scalar($row[28]); }

			 $sthDBF->execute(
				 $lc_recid,
				 $lc_period,
				 $lc_sp_id,
				 $lc_pst,
				 $lc_c_br,
				 $lc_profbr,
				 $lc_d_u,
				 $lc_t_uz,
				 $lc_t_up,
				 $lc_n_u,
				 $lc_vid_u,
				 $lc_cod,
				 $lc_tar,
				 $lc_res,
				 $lc_ds,
				 $lc_fam,
				 $lc_im,
				 $lc_ot,
				 $lc_w,
				 $lc_dr,
				 $lc_sn_pol,
				 $lc_tip,
				 $lc_qq,
				 $lc_c_okato,
				 $lc_v_doc,
				 $lc_s_doc,
				 $lc_n_doc,
				 $lc_xx,
				 $lc_lpu_id
			 );
	 }

	 $connORA->disconnect;
	 $connDBF->disconnect;

};

sub doExpNciVidU
{
	my $self = shift;
	my ($cmd, $ins, $year, $month, $t) = @_;

	my ( $connDBF, $connORA, $sthDBF, @row );

# Step #1 -> create dbf
	$connDBF = $self->createDBF($year, $month, $t);
	$sthDBF = $connDBF->prepare($ins) or die $connDBF->errstr;

	$connORA = $self->connect_to_oracle;
    my $sth  = $connORA->prepare($cmd) or die $connORA->errstr;
	$sth->execute() or die $sth->errstr;

	while((@row = $sth->fetchrow_array)) {
		print $self->proper($row[1])."\n";
		$sthDBF->execute(
			#substr(($row[0] =~ s/^\s+|\s+$//g),1,2),
			$row[0],
			#substr(($row[1] =~ s/^\s+|\s+$//g),1,50)
			$self->proper($row[1])
			);
	}
	$connORA->disconnect;
	$connDBF->disconnect;
}

sub doExpStreets
{
	my $self = shift;
	my ($cmd, $ins, $year, $month, $t) = @_;

	my ( $connDBF, $connORA, $sthDBF, @row );

# Step #1 -> create dbf
	$connDBF = $self->createDBF($year, $month, $t);
	$sthDBF = $connDBF->prepare($ins) or die $connDBF->errstr;

	$connORA = $self->connect_to_oracle;
    my $sth  = $connORA->prepare($cmd) or die $connORA->errstr;
	$sth->execute() or die $sth->errstr;

	while((@row = $sth->fetchrow_array)) {

		$sthDBF->execute(
			$row[0],
			$row[1],
			$row[2],
			$row[3],
			$row[4],
			$row[5],
			$row[6],
			$row[7],
			$row[8],
			LPad($row[9], 8, '0'),
			$row[10],
			$row[11],
			$row[12],
			$row[13],
			$row[14],
			$row[15],
			$row[16]
			) || die $sthDBF->errstr;
	}
	$connORA->disconnect;
	$connDBF->disconnect;

}

sub doExpSegments {
	my $self = shift;
	my ($cmd, $ins, $year, $month, $t) = @_;

	my ( $connDBF, $connORA, $sthDBF, @row );

# Step #1 -> create dbf
	$connDBF = $self->createDBF($year, $month, $t);
	$sthDBF = $connDBF->prepare($ins) or die $connDBF->errstr;

	$connORA = $self->connect_to_oracle;
    my $sth  = $connORA->prepare($cmd) or die $connORA->errstr;
	$sth->execute() or die $sth->errstr;

	while(@row = $sth->fetchrow_array()) {

		$sthDBF->execute(
			$row[0],
			$row[1],
			$row[2],
			$row[3],
			$row[4],
			$row[5],
			$row[6],
			$row[7],
			$row[8],
			$row[9],
			$row[10],
			$row[11],
			$row[12],
			$row[13],
			$row[14],
			$row[15],
			$row[16]
			) or die $sthDBF->errstr;
	}

	$connDBF->disconnect;
	$connORA->disconnect;
}

sub doExpNciRes {
	my $self = shift;
	my ($cmd, $ins, $year, $month, $t) = @_;

	my ( $connDBF, $connORA, $sthDBF, @row );

# Step #1 -> create dbf
	$connDBF = $self->createDBF($year, $month, $t);
	$sthDBF = $connDBF->prepare($ins) or die $connDBF->errstr;

	$connORA = $self->connect_to_oracle;
    my $sth  = $connORA->prepare($cmd) or die $connORA->errstr;
	$sth->execute() or die $sth->errstr;

	while(@row = $sth->fetchrow_array()) {

		$sthDBF->execute(
			$row[0],
			proper($row[1])
			) or die $sthDBF->errstr;
	}
	$connDBF->disconnect;
	$connORA->disconnect;

}

sub doExpSTASMP {
	my $self = shift;
	my ($cmd, $ins, $year, $month, $t) = @_;

	my ( $connDBF, $connORA, $sthDBF, @row );

# Step #1 -> create dbf
	$connDBF = $self->createDBF($year, $month, $t);
	$sthDBF = $connDBF->prepare($ins) or die $connDBF->errstr;

	$connORA = $self->connect_to_oracle;
    my $sth  = $connORA->prepare($cmd) or die $connORA->errstr;
	$sth->execute() or die $sth->errstr;

	while(@row = $sth->fetchrow_array()) {

		$sthDBF->execute(
			$row[0],
			proper($row[1])
			) or die $sthDBF->errstr;
	}

	$connDBF->disconnect;
	$connORA->disconnect;
}


sub doExpBRSP {
	my $self = shift;
	my ($cmd, $ins, $year, $month, $t) = @_;

	my ( $connDBF, $connORA, $sthDBF, @row );

# Step #1 -> create dbf
	$connDBF = $self->createDBF($year, $month, $t);
	$sthDBF = $connDBF->prepare($ins) or die $connDBF->errstr;

	$connORA = $self->connect_to_oracle;
    my $sth  = $connORA->prepare($cmd) or die $connORA->errstr;
	$sth->execute() or die $sth->errstr;

	while(@row = $sth->fetchrow_array()) {

		$sthDBF->execute(
			$row[0],
			$row[1],
			$row[2]
			) or die $sthDBF->errstr;
	}

	$connDBF->disconnect;
	$connORA->disconnect;
}


1;
