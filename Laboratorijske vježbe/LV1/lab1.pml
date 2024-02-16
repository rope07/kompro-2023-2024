// Pero Paskovic, 0036509921
// Predajnik 1 salje pakete prijamniku 1. Predajnik 2 salje pakete prijamniku 2. 
// Vjerojatnost gubitka paketa je 33%, a gubitka potvrde 10%.
// Salje se 14 paketa bez sadrzaja
// postavljena 4 kanala (predajnik-mreza x2 i mreza-prijamnik x2)
// pokrenuto 5 procesa (2 predajnika, 2 prijamnika i 1 mreza

init {
	chan pred_ch1 = [0] of {int, int, int, int};
	chan pred_ch2 = [0] of {int, int, int, int};  
	chan prij_ch1 = [0] of {int, int, int, int};
	chan prij_ch2 = [0] of {int, int, int, int};

	run Predajnik (1,1,pred_ch1); // predajnik 1 salje pakete prijamniku 1
	run Predajnik (2,2,pred_ch2); // predajnik 2 salje pakete prijamniku 2
	run Mreza (pred_ch1,pred_ch2,prij_ch1,prij_ch2);
	run Prijamnik(prij_ch1);
	run Prijamnik(prij_ch2);
}

// proces koji simulira predajnik koji salje paket na kanal
proctype Predajnik(int oznaka_predajnik; int oznaka_prijamnik; chan kanal){
	int br_poruke = 0;
	int oznaka_potvrde; // redni broj paketa na koji dolazi odgovor
	int vrsta_poruke; // 0=paket, 1=odgovor

	do // kanalom se salje oznaka_predajnika, oznaka_prijamnika, redni broj poruke i oznaka da je to paket
	:: (br_poruke < 14) ->
		kanal! oznaka_predajnik,oznaka_prijamnik,br_poruke,0;
		if
		:: timeout -> kanal! oznaka_predajnik,oznaka_prijamnik,br_poruke,0; // retransmisija
		// na kanalu se prima oznaka_predajnika, oznaka_prijamnika, redni broj potvrde i brojka koja predstavlja vrstu poruke
		// primanje oznake potvrde znaci uspjesno odasiljanje paketa i primanje potvrde
		:: kanal? oznaka_predajnik,oznaka_prijamnik,oznaka_potvrde,vrsta_poruke; br_poruke = oznaka_potvrde;
		fi;
	:: else -> break
	od
}

// proces koji simulira komunikacijsku mrezu izmedu predajnika i prijamnika
proctype Mreza(chan pred_ch1; chan pred_ch2; chan prij_ch1; chan prij_ch2){
	int oznaka_predajnik;
	int oznaka_prijamnik;
	int podaci;
	chan izlaz;
	int vrsta_poruke; // 0=paket, 1=odgovor
	int trenutni_predajnik = 0;
	int broj_aktivnih_predajnika = 0;

	do
		:: 	if //biranje kanala na temelju trenutno aktivnog predajnika
			:: (trenutni_predajnik == 0) -> //cekaj dok se odredi prvi posiljatelj
				if
				:: pred_ch2?oznaka_predajnik,oznaka_prijamnik,podaci,vrsta_poruke; izlaz = prij_ch2
				:: pred_ch1?oznaka_predajnik,oznaka_prijamnik,podaci,vrsta_poruke; izlaz = prij_ch1
				fi;
			:: (trenutni_predajnik == 1) ->
				if
				:: prij_ch1? oznaka_predajnik,oznaka_prijamnik,podaci,vrsta_poruke; izlaz = pred_ch1
				:: pred_ch1? oznaka_predajnik,oznaka_prijamnik,podaci,vrsta_poruke; izlaz = prij_ch1
				fi;
			:: (trenutni_predajnik == 2) ->
				if
				:: prij_ch2?oznaka_predajnik,oznaka_prijamnik,podaci,vrsta_poruke; izlaz = pred_ch2
				:: pred_ch2?oznaka_predajnik,oznaka_prijamnik,podaci,vrsta_poruke; izlaz = prij_ch2
				fi;
			fi;

			if //
			:: (trenutni_predajnik == 0) ->
				trenutni_predajnik = oznaka_predajnik;
				broj_aktivnih_predajnika++;
			:: else -> skip
			fi;
	
			if
			:: (vrsta_poruke == 0) -> //ako je poruka paket, gubi se 1/3=33% poruka
				if
				:: izlaz!oznaka_predajnik,oznaka_prijamnik,podaci,0;
				:: izlaz!oznaka_predajnik,oznaka_prijamnik,podaci,0;
				:: (podaci != 13) -> skip;
				fi;
			:: (vrsta_poruke == 1) -> //ako je poruka potvrda, gubi se 1/10=10% poruka
				if
				:: izlaz!oznaka_predajnik,oznaka_prijamnik,podaci,1;
				:: izlaz!oznaka_predajnik,oznaka_prijamnik,podaci,1;
				:: izlaz!oznaka_predajnik,oznaka_prijamnik,podaci,1;
				:: izlaz!oznaka_predajnik,oznaka_prijamnik,podaci,1;
				:: izlaz!oznaka_predajnik,oznaka_prijamnik,podaci,1;
				:: izlaz!oznaka_predajnik,oznaka_prijamnik,podaci,1;
				:: izlaz!oznaka_predajnik,oznaka_prijamnik,podaci,1;
				:: izlaz!oznaka_predajnik,oznaka_prijamnik,podaci,1;
				:: izlaz!oznaka_predajnik,oznaka_prijamnik,podaci,1;
				:: (podaci != 13) -> skip;
				fi;
			fi;			
		
			if //nakon odgovora na zadnji paket prvog predajnika, mijenjamo predajnik
			:: (vrsta_poruke == 1 && podaci == 14) ->
				if
				:: (trenutni_predajnik == 1) -> trenutni_predajnik = 2; broj_aktivnih_predajnika++
				:: (trenutni_predajnik == 2) -> trenutni_predajnik = 1; broj_aktivnih_predajnika++
				fi;
			:: else -> skip
			fi;		
		
			if //nakon zadnjeg odgovora 2. aktivnog predajnika, izlazimo iz do-petlje
			:: (vrsta_poruke == 1 && broj_aktivnih_predajnika == 2 && podaci == 14) ->
				break;
			:: else -> skip
			fi;	
			
	od;
}

// proces koji simulira predajnik koji prima paket, i salje potvrdu
proctype Prijamnik(chan kanal){
	int oznaka_predajnik;
	int oznaka_prijamnik;
	int br_poruke = 0;
	int vrsta_poruke; // 0=paket, 1=odgovor

	do // kanalom se prima paket te se istim kanalom salje potvrda
		:: (br_poruke < 14) ->
			// na kanalu se primaju oznaka_predajnika, oznaka_prijamnika, redni broj primljene poruke
			kanal? oznaka_predajnik,oznaka_prijamnik,br_poruke,vrsta_poruke;
			br_poruke++;
			// na kanal se stavljaju oznaka_predajnika, oznaka_prijamnika, redni broj poruke te oznaka da je poruka potvrda
			kanal! oznaka_predajnik,oznaka_prijamnik,br_poruke,1;
		:: else -> break
	od;
}