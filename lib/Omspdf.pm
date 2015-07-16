
package Omspdf;

use strict;
use warnings;

use Encode;
use Carp qw(croak);

use PDF::API2;
use PDF::Table;

use constant mm => 25.4 / 72;
use constant in => 1 / 72;
use constant pt => 1;

our $VERSION = '0.01';

sub new {
    my ($class, $args) = @_;
    my $self = {
	nameF    => $args->{nameF}  || "$0.pdf",
	is_file   => $args->{is_file} || 0 # if 0 - rename file. if 1 - delete file
    };

    bless $self, $class;

	return $self;
}

sub CreatePdf {
  my $self = shift;
  croak "Illegal parameter list of number of values"  if @_ != 5;

  # для заполнения документа должна быть получена дата его создания
  my ($nowday,$nowmonth,$nowyear,$nowhour,$nowminute)=(localtime)[3,4,5,2,1];
  $nowyear+=1900;

  my ($month, $year, $cntOrders, $sumTarif, $glvr_name) = @_;
  my ( $paragraph1, $paragraph2, $paragraph3, $paragraph4 ) = get_data();
  my $pdftable = PDF::Table->new;

  my $pdf = PDF::API2->new( -file => "$self->{nameF}" );

  my $page = $pdf->page;

  $page->mediabox('A4');

  my $tbldata = [
      [decode('utf8','Количество вызовов (записей в реестр счетов)'),
      decode('utf8','Страховая стоимость по тарифу, всего (руб., коп.)')
      ],
    ["1",
    "2"],
    ["$cntOrders",
     "$sumTarif"],
  ];


  my %font = (
    Helvetica => {
        Bold   => $pdf->ttfont('/usr/share/fonts/msttcore/arialbd.ttf'),
        Roman  => $pdf->ttfont('/usr/share/fonts/msttcore/arial.ttf'),
        Italic => $pdf->ttfont('/usr/share/fonts/msttcore/ariali.ttf'),
    },
    Times => {
        Bold   => $pdf->ttfont('/usr/share/fonts/msttcore/timesbd.ttf'),
        Roman  => $pdf->ttfont('/usr/share/fonts/msttcore/times.ttf'),
        Italic => $pdf->ttfont('/usr/share/fonts/msttcore/timesi.ttf'),
    },
  );


  my $headline_text = $page->text;
  $headline_text->font( $font{'Times'}{'Bold'}, 14 / pt );
  $headline_text->fillcolor('black');
  $headline_text->translate( 110 / mm, 277 / mm );
  $headline_text->text_center(decode('utf8','ПАСПОРТ СЧЕТА'));

  my $left_column_text = $page->text;
  $left_column_text->font( $font{'Times'}{'Roman'}, 14 / pt );
  $left_column_text->fillcolor('black');

  my ( $endw, $ypos, $paragraph ) = text_block(
    $left_column_text,
      decode('utf8',$paragraph1),
      -x        => 30 / mm,
      -y        => 258 / mm,
      -w        => 160 / mm,
      -h        => 110 / mm - 18 / pt,
      -lead     => 18 / pt,
      -parspace => 0 / pt,
      -align    => 'justify',
  );


  my $black_line = $page->gfx;
  $black_line->strokecolor('black');
  $black_line->move( 33 / mm, $ypos + 5 / mm );
  $black_line->line( 185 / mm, $ypos + 5 / mm );
  $black_line->stroke;

  $left_column_text->font( $font{'Times'}{'Roman'}, 10 / pt );
  $left_column_text->fillcolor('black');
  ( $endw, $ypos, $paragraph ) = text_block(
      $left_column_text,
      decode('utf8','(наименование организации-плательщика)'),
      -x        => 60 / mm,
      -y        => $ypos + 1 / mm,
      -w        => 100 / mm,
      -h        => 110 / mm - 8 / pt,
      -lead     => 8 / pt,
      -parspace => 0 / pt,
      -align    => 'center',
  );


  $left_column_text = $page->text;
  $left_column_text->font( $font{'Times'}{'Bold'}, 14 / pt );
  $left_column_text->fillcolor('black');
  ( $endw, $ypos, $paragraph ) = text_block(
    $left_column_text,
      #decode('utf8',$paragraph2),
      #
      decode('utf8',"за ".getRMonth($month+0)." $year года"),
      -x        => 90 / mm,
      -y        => $ypos - 10 / mm,
      -w        => 60 / mm,
      -h        => 110 / mm - 8 / pt,
      -lead     => 8 / pt,
      -parspace => 0 / pt,
      -align    => 'justify',
  );

  $left_column_text->font( $font{'Times'}{'Roman'}, 10 / pt );
  $left_column_text->fillcolor('black');
  ( $endw, $ypos, $paragraph ) = text_block(
      $left_column_text,
      decode('utf8','(месяц)'),
      -x        => 80 / mm,
      -y        => $ypos - 1 / mm,
      -w        => 40 / mm,
      -h        => 40 / mm - 8 / pt,
      -lead     => 8 / pt,
      -parspace => 0 / pt,
      -align    => 'center',
  );



  my $left_edge_of_table = 135;

  my $cell_props = [];
      $cell_props->[1][0] = {
	  #Row 2 cell 1
	  background_color => '#FFFFFF',
	  font_color       => 'black',
	  font_size        => 12,
      };
      $cell_props->[1][1] = {
	  #Row 2 cell 2
	  background_color => '#FFFFFF',
	  font_color       => 'black',
	  font_size        => 12,
      };

  # Таблица
  # build the table layout
  $pdftable->table(
      # required params
      $pdf,
      $page,
      $tbldata,
      x => $left_edge_of_table,
      w => 135 / mm,
      start_y => $ypos - 5 / mm,
      start_h => 50 / mm,
      padding => 3,
      background_color_odd  => "white",
      background_color_even => "white",
      font => $pdf->ttfont('/usr/share/fonts/msttcore/times.ttf'),
      justify    => 'center',
      font_size  => 14,
      cell_props => $cell_props,
    );



  my $right_column_text = $page->text;
  $right_column_text->font( $font{'Times'}{'Roman'}, 12 / pt );
  $right_column_text->fillcolor('black');
  ( $endw, $ypos, $paragraph ) = text_block(
      $right_column_text,
      decode('utf8',"От организации СМП Главный врач СС и НМП ").$glvr_name,
      -x        => 30 / mm,
      -y        => $ypos - 40 / mm,
      -w        => 150 / mm,
      -h        => 54 / mm,
      -lead     => 14 / pt,
      -parspace => 0 / pt,
      -align    => 'left',
  );

  $left_column_text->font( $font{'Times'}{'Roman'}, 8 / pt );
  $left_column_text->fillcolor('black');
  ( $endw, $ypos, $paragraph ) = text_block(
      $left_column_text,
      decode('utf8','(должность,фамилия,имя,отчество,подпись)'),
      -x        => 50 / mm,
      -y        => $ypos + 1 / mm,
      -w        => 100 / mm,
      -h        => 16 / mm - 8 / pt,
      -lead     => 8 / pt,
      -parspace => 0 / pt,
      -align    => 'center',
  );
  # МП
  $left_column_text->font( $font{'Times'}{'Roman'}, 14 / pt );
  $left_column_text->fillcolor('black');
  ( $endw, $ypos, $paragraph ) = text_block(
      $left_column_text,
      decode('utf8','МП'),
      -x        => 30 / mm,
      -y        => $ypos - 10 / mm,
      -w        => 30 / mm,
      -h        => 16 / mm - 8 / pt,
      -lead     => 8 / pt,
      -parspace => 0 / pt,
      -align    => 'left',
  );

  # Дата
  $left_column_text->font( $font{'Times'}{'Roman'}, 14 / pt );
  $left_column_text->fillcolor('black');
  ( $endw, $ypos, $paragraph ) = text_block(
      $left_column_text,
      decode('utf8',"Дата ".$nowday." ".getRMonth($nowmonth)." ".$nowyear." г."),
      -x        => 30 / mm,
      -y        => $ypos - 10 / mm,
      -w        => 100 / mm,
      -h        => 16 / mm - 8 / pt,
      -lead     => 8 / pt,
      -parspace => 0 / pt,
      -align    => 'left',
  );

  #Пунктирная линия
  $black_line = $page->gfx;
  $black_line->strokecolor('black');
  $black_line->move( 30 / mm, $ypos - 10 / mm );
  $black_line->line( 190 / mm, $ypos - 10 / mm );
  $black_line->linedash( 4 );
  $black_line->stroke;

  # Протокол....
  $left_column_text->font( $font{'Times'}{'Bold'}, 12 / pt );
  $left_column_text->fillcolor('black');
  ( $endw, $ypos, $paragraph ) = text_block(
      $left_column_text,
      decode('utf8','Протокол электронной версии заявленного счета:'),
      -x        => 30 / mm,
      -y        => $ypos - 15 / mm,
      -w        => 150 / mm,
      -h        => 16 / mm - 8 / pt,
      -lead     => 14 / pt,
      -parspace => 0 / pt,
      -align    => 'left',
  );


  $left_column_text->font( $font{'Times'}{'Roman'}, 12 / pt );
  $left_column_text->fillcolor('black');
  ( $endw, $ypos, $paragraph ) = text_block(
      $left_column_text,
      decode('utf8',$paragraph3),
      -x => 30 / mm,
      -y => $ypos - 1 /mm,
      -w => 150 / mm,
      -h => 50 / mm - 10 / pt,
      -lead     => 14 / pt,
      -parspace => 0 / pt,
      -align    => 'left',
  );

  # линия
  $black_line = $page->gfx;
  $black_line->strokecolor('black');
  $black_line->linedash();
  $black_line->move( 30 / mm, $ypos - 5 / mm );
  $black_line->line( 130 / mm, $ypos - 5 / mm );
  $black_line->move( 150 / mm, $ypos - 5 / mm );
  $black_line->line( 190 / mm, $ypos - 5 / mm );
  $black_line->stroke;

  $left_column_text->font( $font{'Times'}{'Roman'}, 10 / pt );
  $left_column_text->fillcolor('black');
  ( $endw, $ypos, $paragraph ) = text_block(
      $left_column_text,
      decode('utf8','(должность,фамилия,имя,отчество)'),
      -x        => 30 / mm,
      -y        => $ypos - 8 / mm,
      -w        => 80 / mm,
      -h        => 10 / mm,
      -lead     => 10 / pt,
      -parspace => 0 / pt,
      -align    => 'center',
  );

  $left_column_text->font( $font{'Times'}{'Roman'}, 10 / pt );
  $left_column_text->fillcolor('black');
  ( $endw, $ypos, $paragraph ) = text_block(
      $left_column_text,
      decode('utf8','(подпись)'),
      -x        => 150 / mm,
      -y        => $ypos + 4 / mm,
      -w        => 50 / mm,
      -h        => 10 / mm,
      -lead     => 10 / pt,
      -parspace => 0 / pt,
      -align    => 'center',
  );

  # Дата
  $left_column_text->font( $font{'Times'}{'Roman'}, 12 / pt );
  $left_column_text->fillcolor('black');
  ( $endw, $ypos, $paragraph ) = text_block(
      $left_column_text,
      decode('utf8',"Дата _______________________ $year г."),
      -x        => 30 / mm,
      -y        => $ypos - 10 / mm,
      -w        => 100 / mm,
      -h        => 16 / mm - 8 / pt,
      -lead     => 8 / pt,
      -parspace => 0 / pt,
      -align    => 'left',
  );

  # Подверждение.....
  $left_column_text->font( $font{'Times'}{'Bold'}, 12 / pt );
  $left_column_text->fillcolor('black');
  ( $endw, $ypos, $paragraph ) = text_block(
      $left_column_text,
      decode('utf8','Подтверждение о приемке ИП:'),
      -x        => 30 / mm,
      -y        => $ypos - 10 / mm,
      -w        => 150 / mm,
      -h        => 16 / mm - 8 / pt,
      -lead     => 14 / pt,
      -parspace => 0 / pt,
      -align    => 'left',
  );
  # Подверждение.....
  $left_column_text->font( $font{'Times'}{'Roman'}, 12 / pt );
  $left_column_text->fillcolor('black');
  ( $endw, $ypos, $paragraph ) = text_block(
      $left_column_text,
      decode('utf8',$paragraph4),
      -x        => 30 / mm,
      -y        => $ypos - 1 / mm,
      -w        => 150 / mm,
      -h        => 14 / mm - 8 / pt,
      -lead     => 1 / pt,
      -parspace => 0 / pt,
      -align    => 'left',
  );

  # линия
  $black_line = $page->gfx;
  $black_line->strokecolor('black');
  $black_line->linedash();
  $black_line->move( 30 / mm, $ypos - 5 / mm );
  $black_line->line( 130 / mm, $ypos - 5 / mm );
  $black_line->move( 150 / mm, $ypos - 5 / mm );
  $black_line->line( 190 / mm, $ypos - 5 / mm );
  $black_line->stroke;

  $left_column_text->font( $font{'Times'}{'Roman'}, 10 / pt );
  $left_column_text->fillcolor('black');
  ( $endw, $ypos, $paragraph ) = text_block(
      $left_column_text,
      decode('utf8','(должность,фамилия,имя,отчество)'),
      -x        => 30 / mm,
      -y        => $ypos - 8 / mm,
      -w        => 80 / mm,
      -h        => 10 / mm,
      -lead     => 10 / pt,
      -parspace => 0 / pt,
      -align    => 'center',
  );

  $left_column_text->font( $font{'Times'}{'Roman'}, 10 / pt );
  $left_column_text->fillcolor('black');
  ( $endw, $ypos, $paragraph ) = text_block(
      $left_column_text,
      decode('utf8','(подпись)'),
      -x        => 150 / mm,
      -y        => $ypos + 4 / mm,
      -w        => 50 / mm,
      -h        => 10 / mm,
      -lead     => 10 / pt,
      -parspace => 0 / pt,
      -align    => 'center',
  );

  # Дата
  $left_column_text->font( $font{'Times'}{'Roman'}, 12 / pt );
  $left_column_text->fillcolor('black');
  ( $endw, $ypos, $paragraph ) = text_block(
      $left_column_text,
      decode('utf8',"Дата ______________ $year г."),
      -x        => 30 / mm,
      -y        => $ypos - 10 / mm,
      -w        => 100 / mm,
      -h        => 16 / mm - 8 / pt,
      -lead     => 8 / pt,
      -parspace => 0 / pt,
      -align    => 'left',
  );


  $pdf->save;
  $pdf->end();

  return $self->{nameF};


}

sub text_block {

    my $text_object = shift;
    my $text        = shift;

    my %arg = @_;


    my $endw = 0;
    # Get the text in paragraphs
    my @paragraphs = split( /\n/, $text );

    # calculate width of all words
    my $space_width = $text_object->advancewidth(' ');

    my @words = split( /\s+/, $text );
    my %width = ();
    foreach (@words) {
        next if exists $width{$_};
        $width{$_} = $text_object->advancewidth($_);
    }

    my $ypos = $arg{'-y'};
    my @paragraph = split( / /, shift(@paragraphs) );

    my $first_line      = 1;
    my $first_paragraph = 1;

    # while we can add another line

    while ( $ypos >= $arg{'-y'} - $arg{'-h'} + $arg{'-lead'} ) {

        unless (@paragraph) {
            last unless scalar @paragraphs;

            @paragraph = split( / /, shift(@paragraphs) );

            $ypos -= $arg{'-parspace'} if $arg{'-parspace'};
            last unless $ypos >= $arg{'-y'} - $arg{'-h'};

            $first_line      = 1;
            $first_paragraph = 0;
        }

        my $xpos = $arg{'-x'};

        # while there's room on the line, add another word
        my @line = ();

        my $line_width = 0;
        if ( $first_line && exists $arg{'-hang'} ) {

            my $hang_width = $text_object->advancewidth( $arg{'-hang'} );

            $text_object->translate( $xpos, $ypos );
            $text_object->text( $arg{'-hang'} );

            $xpos       += $hang_width;
            $line_width += $hang_width;
            $arg{'-indent'} += $hang_width if $first_paragraph;

        }
        elsif ( $first_line && exists $arg{'-flindent'} ) {

            $xpos       += $arg{'-flindent'};
            $line_width += $arg{'-flindent'};

        }
        elsif ( $first_paragraph && exists $arg{'-fpindent'} ) {

            $xpos       += $arg{'-fpindent'};
            $line_width += $arg{'-fpindent'};

        }
        elsif ( exists $arg{'-indent'} ) {

            $xpos       += $arg{'-indent'};
            $line_width += $arg{'-indent'};

        }

        while ( @paragraph
            and $line_width + ( scalar(@line) * $space_width ) +
            $width{ $paragraph[0] } < $arg{'-w'} )
        {

            $line_width += $width{ $paragraph[0] };
            push( @line, shift(@paragraph) );

        }

        # calculate the space width
        my ( $wordspace, $align );
        if ( $arg{'-align'} eq 'fulljustify'
            or ( $arg{'-align'} eq 'justify' and @paragraph ) )
        {

            if ( scalar(@line) == 1 ) {
                @line = split( //, $line[0] );

            }
            $wordspace = ( $arg{'-w'} - $line_width ) / ( scalar(@line) - 1 );

            $align = 'justify';
        }
        else {
            $align = ( $arg{'-align'} eq 'justify' ) ? 'left' : $arg{'-align'};

            $wordspace = $space_width;
        }
        $line_width += $wordspace * ( scalar(@line) - 1 );

        if ( $align eq 'justify' ) {
            foreach my $word (@line) {

                $text_object->translate( $xpos, $ypos );
                $text_object->text($word);

                $xpos += ( $width{$word} + $wordspace ) if (@line);

            }
            $endw = $arg{'-w'};
        }
        else {

            # calculate the left hand position of the line
            if ( $align eq 'right' ) {
                $xpos += $arg{'-w'} - $line_width;

            }
            elsif ( $align eq 'center' ) {
                $xpos += ( $arg{'-w'} / 2 ) - ( $line_width / 2 );

            }

            # render the line
            $text_object->translate( $xpos, $ypos );

            $endw = $text_object->text( join( ' ', @line ) );

        }
        $ypos -= $arg{'-lead'};
        $first_line = 0;

    }
    unshift( @paragraphs, join( ' ', @paragraph ) ) if scalar(@paragraph);

    return ( $endw, $ypos, join( "\n", @paragraphs ) )

}


### SAVE ROOM AT THE TOP ###
sub get_data {
    (
qq|За вызовы, выполненные бригадами Государственного бюджетного учреждения города Москвы «Станция скорой и неотложной медицинской помощи им. А.С. Пучкова» Департамента здравоохранения города Москвы
в Московский городской фонд обязательного медицинского страхования|,
qq|за май 2015 года|,
qq|Имя архивного файла ………………. Дата создания ……..………
Количество вложений в архивном файле, всего …………………..
Подготовил (от учреждения СМП):|,
qq|Страховая стоимость заявленного счета: ………………………………. (руб., коп.)|,
    );
}

sub getRMonth {
#  my $self = shift;
  my $mon = shift @_;

  my @arrMonth =  (
    'январь',
    'февраль',
    'март',
    'апрель',
    'май',
    'июнь',
    'июль',
    'август',
    'сентябрь',
    'октябрь',
    'ноябрь',
    'декабрь'
   );

  return $arrMonth[$mon];
}

1;
