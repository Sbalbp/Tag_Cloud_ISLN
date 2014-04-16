#!"C:\xampp\perl\bin\perl.exe"

    use 5.010;
    use strict;
	use LWP::Simple;
	use XML::Parser;
	use HTML::Parser;
	use CGI qw(param);
	use CGI::Cookie;
	
	my $entrada;
	my $feed;
	my $cdata = 1;
	my $flag1 = 0;
	my $peso = 1;
	my %contador;
	# Numero de palabras en total
	my $total = 0;
	
	# Variables para los links y titulos
	my %links;
	my $es_item=0;
	my $es_link=0;
	my $es_titulo=0;
	my $es_desc=0;
	my $num_links=0;
	my @titulos;
	my @descriptions;
	my $cad_titulo;
	my @extr;
	my $busqueda=0;
	my @busq_arr;
	my @apariciones;
	my %display;
	my %num_count;
	
	# Parametros en funcion de la lengua preferida del navegador
	my $salir = 0;
	my $lang = substr($ENV{HTTP_ACCEPT_LANGUAGE},0,2);
	my $cod_lang = 0;
	my @reductor = (150,1);
	my @stwd_file = ("stopwords_es.txt","stopwords_en.txt");
	my @boton_txt = ("Buscar", "Search");
	my @ayuda1_txt = ("Introduzca el tipo de feed: ", "Input feed type: ");
	my @ayuda2_txt = ("Tipos de feed posibles: 'Internacional', 'Cultura', 'Deportes', 'Sociedad'",
					 "Accepted feed types: 'Top', 'World', 'Business', 'Technology'");
	my @ayuda3_txt = ("Palabra a buscar: ", "Word to search for: ");
	my @exito_txt = ("Resultados de la búsqueda:","Search results:");
	my @fracaso_txt = ("No se encontraron resultados para ","No results found for ");
	my %url_en;
	$url_en{"top"} = "http://feeds.bbci.co.uk/news/rss.xml?edition=uk";
	$url_en{"world"} = "http://feeds.bbci.co.uk/news/world/rss.xml?edition=uk";
	$url_en{"business"} = "http://feeds.bbci.co.uk/news/business/rss.xml?edition=uk";
	$url_en{"technology"} = "http://feeds.bbci.co.uk/news/technology/rss.xml?edition=uk";
	
	# Expresiones regulares y variables para la deteccion de nombres propios
	my $May = '[A-ZÁÉÍÓÚÄËÏÖÜÑÇ]';
	my $Min = '[a-záéíóúäëïöüñàèìòùãõç]';
	my $Empieza_May = "(?:$May(?:$Min|$May)+)";
	my $Nombre = "(?:$Empieza_May(?:(?:(?: de)|(?: la)|(?: del)|(?: el))? $Empieza_May)*)";
	my @Nombres;
	my @auxN;
	
	my $aux;
	my @palabras;
	my @stopwords;
	my %contador;
	my @lista_final;
	
	my $pal_it;
	my %totales;
	my %idfs;
	my %enlaces;
	

	# INICIO DEL PROGRAMA
	
	# La salida sera en UTF-8
	binmode(STDOUT, ":utf8");
	
	# Reconocemos la lengua preferida del navegador
	if($lang eq "es"){
		$cod_lang = 0;
	}
	else{
		$cod_lang = 1;
	}
	
	my %cookies = CGI::Cookie->fetch;
	if(defined $cookies{"lan"} and defined $cookies{"lan"}->value){
		$cod_lang = $cookies{"lan"}->value;
	}

	if(param){
		$entrada = lc(param('feed'));
		$busqueda = param('bq');
		utf8::decode($busqueda);
		if(!(param('lan') eq "")){
			$cod_lang = param('lan');
		}
		@busq_arr = split(/[ ]*,[ ]*/,$busqueda);
	}
	else{
		$salir = 1;
	}
	
	
	my $xml_parser = new XML::Parser(Style=>'Subs', Handlers=>{CdataStart => \&cdata_start, CdataEnd => \&cdata_end, 
																Char => \&caracteres, Start => \&inicio, End=> \&fin});
	
	# Leemos las stopwords
	open STPW, "<",$stwd_file[$cod_lang];
	@stopwords = <STPW>;
	foreach (reverse(@stopwords)){
		chomp($_);
	}
		
	# Cabeceras
	print  "Content-type: text/html\n\n";
	print "<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n</head>\n<body>\n";
	# Javascript
	print "<script type=\"text/javascript\" language=\"JavaScript\">\n";
	print
	"
	
		function setCookie(c_name,value,exdays){
			var exdate=new Date();
			exdate.setDate(exdate.getDate() + exdays);
			var c_value=escape(value) + ((exdays==null) ? \"\" : \"; expires=\"+exdate.toUTCString());
			document.cookie=c_name + \"=\" + c_value;
		}
		
		function getCookie(c_name){
			var c_value = document.cookie;
			var c_start = c_value.indexOf(\" \" + c_name + \"=\");
			if (c_start == -1){
				c_start = c_value.indexOf(c_name + \"=\");
			}
			if (c_start == -1){
				c_value = null;
			}
			else{
				c_start = c_value.indexOf(\"=\", c_start) + 1;
				var c_end = c_value.indexOf(\";\", c_start);
				if (c_end == -1){
					c_end = c_value.length;
				}
				c_value = unescape(c_value.substring(c_start,c_end));
			}
			return c_value;
		}
	
		function myFunction(){
			document.getElementById(\"demo\").innerHTML=\"Hello World\";
		}
	";	
	print "</script>\n";

	# Formularios
	print "<hr>";
	print "\n<div align=center><form name=\"lenguajes\" action=\"script.pl\"><input onclick=\"setCookie('lan',0,365)\" type=\"image\" src=\"../images/lan0.gif \">";
	print "\n<input onclick=\"setCookie('lan',1,365)\" type=\"image\" src=\"../images/lan1.gif\"></form></div>";
	print"<form name=\"input\" action=\"script.pl\" method=\"get\">
			$ayuda1_txt[$cod_lang] <input type=\"text\" name=\"feed\"><p>
			$ayuda3_txt[$cod_lang] <input type=\"text\" name=\"bq\"><p>
			<input type=\"submit\" value=\"$boton_txt[$cod_lang]\">
			</form>\n";
	print "$ayuda2_txt[$cod_lang]";
	print "<hr>";
			
	if($salir == 1){
		return;
	}
	else{
		# Bajamos el xml con el feed e iniciamos el parser
		if($cod_lang == 0){
			$feed = get("http://ep00.epimg.net/rss/$entrada/portada.xml");
		}
		else{
			$cdata = 0;
			$feed = get($url_en{$entrada});#"http://feeds.bbci.co.uk/news/rss.xml");
		}
		$xml_parser->parse($feed);
	}
	print "<p>";

	
	# Lectura del archivo con las frecuencias de palabras en castellano
	my %frecuencias_archivo;
	my %frecuencias_noticia;
	my @extract;
	my $valor;
	my @txt;
	open FRECS, "<:utf8","frecuencias_es.txt";
	@txt = <FRECS>;
	foreach (@txt){
		chomp $_;
		@extract = $_ =~ m/[ ]+\d+\.[\W]+([\wáéíóúäëïöüñç]+)[\W]+(?:\d+,)*\d+[\W]+(\d+\.\d+)/g;
		$valor = $extract[1];
		$frecuencias_archivo{$extract[0]}=$valor+0;
	}
	
	
	# Filtrado  para arreglar títulos
	foreach (@titulos){
		@extr = $_ =~ m/[^\w]*([\w :,()'?¿%\.]*)[^\w]*/g;
		$_ = join(" ",@extr);
	}
	
	# Filtro previo de los valores de contador
	foreach (sort(keys(%contador))){
	
		# Comprobamos si tiene plurales (terminan en -s -es -as)
		if(exists $contador{$_."s"}){
			$contador{$_} += $contador{$_."s"};
			$contador{$_."s"} = 0;
		}
		if(exists $contador{$_."es"}){
			$contador{$_} += $contador{$_."es"};
			$contador{$_."es"} = 0;
		}
		if(exists $contador{$_."as"}){
			$contador{$_} += $contador{$_."as"};
			$contador{$_."as"} = 0;
		}
		
		# Frec_noticia / Frec_archivo
		if(!(exists $frecuencias_archivo{$_})){
			$frecuencias_archivo{$_} = 1;
		}
	
		$frecuencias_noticia{$_}=((($contador{$_}/$total)*1000000)+100)/$frecuencias_archivo{$_};		
		
	}
	
	# Si no estamos buscando noticias para una palabra mostraremos el feed
	if($busqueda eq ""){
		# Escribimos cada palabra en el HTML con mas o menos tamaño en funcion de su frecuencia
		my $palabras_dib = 0; # Maximo 100 palabras
		$aux = 0;
		foreach (sort {$frecuencias_noticia{$b} <=> $frecuencias_noticia{$a} } keys %frecuencias_noticia){
			
			# Si no es un stopword  y aparece suficientes veces lo escribimos en el html
			if(!($_ ~~ @stopwords) && $contador{$_}>0){
			
				push(@lista_final,$_);
				
				$palabras_dib++;
			}
		
			if($palabras_dib == 100){
				last;
			}
		}

		$aux = 0;
		foreach (sort(@lista_final)){
			if($aux < 9){
					print "<a href=\"script.pl?feed=$entrada&bq=$_\"><span title=\"frecuencia $_\" style=\"font-size: ".(8+$contador{$_}/$reductor[$cod_lang])."pt\"> $display{$_} </span></a>&nbsp;&nbsp;";
			}
			else{
				print "<a href=\"script.pl?feed=$entrada&bq=$_\"><span title=\"frecuencia $_\" style=\"font-size: ".(8+$contador{$_}/$reductor[$cod_lang])."pt\"> $display{$_} </span></a></p>\n<p>";
				$aux = -1;
			}
			$aux++;
		}
	}
	# En caso de estar mostrando la lista de noticias relacionadas
	else{
	
		# Para cada termino de busqueda calculamos su IDF y sumamos IDF*apariciones del termino en cada enlace
		foreach (@busq_arr){
			# Calculo del idf
			$idfs{$_}=idf($_);
			$pal_it=$_;
			# Para cada enlace...
			foreach (0..$#apariciones){
				if(exists $apariciones[$_]{$pal_it}){
					$enlaces{$_}+=$apariciones[$_]{$pal_it}*$idfs{$pal_it};
				}
			}
		}

		# Para cada enlace calculamos cuantas palabras tiene y normalizamos el factor IDF*apariciones/total_palabras
		foreach (0..$#apariciones){
			$pal_it = $_;
			foreach (keys($apariciones[$_])){
				$totales{$pal_it}+=$apariciones[$pal_it]{$_};
			}
			$enlaces{$_} = $enlaces{$_}/$totales{$_};
		}
		
		my %rlinks = reverse %links;
		my $veces_print = 0;
		print "<p><b>$exito_txt[$cod_lang]</b><p>";
		
		# Escribimos los resultados en orden decreciente del factor IDF*apariciones/total_palabras
		foreach (sort {$enlaces{$b} <=> $enlaces{$a} } keys %enlaces){
			if($enlaces{$_} > 0){
				print "<p><a href=\"$rlinks{$_}\">$titulos[$_]</a><p>$descriptions[$_]<p>";
				$veces_print++;
			}
		}
		
		if($veces_print == 0){
			print "<p>$fracaso_txt[$cod_lang]'@busq_arr'<p>";
		}
	}

	
	print "</body>\n</html>\n";

	sub cdata_start{
		if($flag1 == 1){
			$flag1 = 3;
		}
		if($flag1 == 2){
			$flag1 = 4;
		}
		if($es_link == 1){
			$flag1+=2;
		}
	}
	
	sub cdata_end{
		if($flag1 == 3){
			$flag1 = 1;
		}
		if($flag1 == 4){
			$flag1 = 2;
		}
		if($es_link == 1){
			$flag1-=2;
		}
	}
	
	sub caracteres{
		sub start{
			if( ${$_[1]}[0] eq "p" || ${$_[1]}[0] eq "em" || ${$_[1]}[0] eq "a"){
				$peso+=3;
			}
		}
		
		sub end{
			if( ${$_[1]}[0] eq "p" || ${$_[1]}[0] eq "em" || ${$_[1]}[0] eq "a"){
				$peso-=3;
			}
		}
		
		sub text{
			my $cad_aux = join('',@_);
			
			# Nombre propio
			@Nombres = $cad_aux =~ /(?:\b)($Nombre)/g;
			$cad_aux =~ s/(?:\b)($Nombre)//g;	
			foreach(@Nombres){
				@auxN = split /\b/, $_;
				if(!(lc($auxN[0]) ~~ @stopwords)){
					if($#auxN >= 1){
						$contador{$_}+=$peso*2;
						$apariciones[$num_links]{$_}+=$peso*2;
						$display{$_}=$_;
					}
					else{
						$contador{lc($_)}+=$peso;
						$apariciones[$num_links]{lc($_)}+=$peso;
						$display{lc($_)}=$_;
					}
				}
				$total++;
			}
			
			@palabras = split /[\b\W\d]+/, $cad_aux;
			foreach (@palabras){
				$contador{lc($_)}+=$peso;
				$total++;
				$apariciones[$num_links]{lc($_)}+=$peso;
				$display{lc($_)}=$_;
			}
		}
	
		# Seccion de texto de content:encoded
		if($flag1==3){
		
			# Si es una descripcion la extraemos
			if($es_desc){
				$descriptions[$num_links]=$_[1];
			}
			
			# Al ser HTML, utilizamos un parser de HTML para extraer el texto
			my $p =  HTML::Parser->new( api_version => 3,
                         start_h => [\&start, "self, tokens"],
                         end_h   => [\&end,   "tagname, attr, attrseq, dtext"],
						 text_h =>  [\&text, "dtext" ],
                         marked_sections => 1,
                       );
			
			$p->parse($_[1]);
		}
		if($flag1==4){
			# Si es un titulo extraemos el mismo
			if($es_titulo){
				$titulos[$num_links]=$_[1];
			}
			# Si es una descripcion la extraemos
			if($es_desc){
				$descriptions[$num_links]=$_[1];
			}
		
			# Nombre propio
			@Nombres = $_[1] =~ /(?:\b)($Nombre)/g;
			$_[1] =~ s/(?:\b)($Nombre)//g;
			# Procesado de nombres propios
			foreach(@Nombres){
				@auxN = split /\b/, $_;
				if(!(lc($auxN[0]) ~~ @stopwords)){
					if($#auxN >= 1){
						$contador{$_}+=$peso*2;
						$apariciones[$num_links]{$_}+=$peso*2;
						$display{$_}=$_;
					}
					else{
						$contador{lc($_)}+=$peso;
						$apariciones[$num_links]{lc($_)}+=$peso;
						$display{lc($_)}=$_;
					}
				}
				$total++;
			}
		
			# Procesado del resto de palabras
			@palabras = split /[\b\W\d]+/, $_[1];
			foreach(@palabras){						
				$contador{lc($_)}+=$peso;
				$total++;
				$apariciones[$num_links]{lc($_)}+=$peso;
				$display{lc($_)}=$_;
			}
		}
		
		# Deteccion de enlaces
		if($es_link == 1){
			$links{$_[1]}=$num_links;
		}
	}
	
	sub inicio{
		if($_[1] eq "content:encoded" && $es_item==1){
			if($cdata == 1){
				$flag1 = 1;
			}
			else{
				$flag1 = 3;
			}
		}
		if($_[1] eq "category" || $_[1] eq "title" || $_[1] eq "description" && $es_item==1){
			if($_[1] eq "title"){
				$es_titulo = 1;
			}
			if($_[1] eq "description"){
				$es_desc = 1;
			}
		
			if($cdata == 1){
				$flag1 = 2;
			}
			else{
				$flag1 = 4;
			}
		}
		if($_[1] eq "link" && $es_item==1){
			$es_link=1;
		}
		if($_[1] eq "item"){
			$es_item=1;
		}
	}
	
	sub fin{
		if($_[1] eq "content:encoded" || $_[1] eq "category" || $_[1] eq "title" || $_[1] eq "description" && $es_item==1){
			$flag1 = 0;
			$es_titulo = 0;
			$es_desc = 0;
		}
		if($_[1] eq "link" && $es_item==1){
			$es_link=0;
		}
		if($_[1] eq "item"){
			$es_item=0;
			$num_links++;
		}
	}
	
	sub idf{
		my $palabra = $_[0];
		my $veces_palabra = 0;
		my $idf = 0;
		
		foreach (0..$#apariciones){
			if(exists $apariciones[$_]{$palabra}){
				$veces_palabra++;
			}
		}
		
		if($veces_palabra==0){
			return 0;
		}
		
		$idf = log($#apariciones/$veces_palabra);
		return $idf;
	}
