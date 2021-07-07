constants.py
	- Parametre
		○ Objekttype
		○ Områdenavn
		○ Kommunenummer fra og til 
		○ Lokal sti
		○ Stier til ontologier

run_nvdb2rdf.py
	- Script for bulk-kjøring av å lese data fra NVDB-API og skrive til RDF i henhold til NVDB-OWL
	- Kjører kommunevis (fra-til kommunenummer) for valgt objekttype gjennom funksjonen nvdb2graph fra nvdb2rdf.py, skriver til felles RDF-fil med navn basert på områdenavn

nvdb2rdf.py
	- Prosedyrer for konvertering fra NVDB-API til RDF i henhold til NVDB-OWL
	- nvdb2graph: Henter data fra NVDB-API (for valgt kommune og objekttype) gjennom funksjonen nvdbFagdata fra nvdbapiv3.py, og skriver til intern graf. 

ndvbapiv3.py
	- Bibliotek for å lese data fra NVDB-API, or returnere som et håndterbart objekt
	- nvdbFagdata er funksjonen for selve lesingen
	- Modifisert fra Jan Kristian sitt script.

mappingNVDB2GDF.py
	- Konverterer fra RDF basert på NVDB-OWL til RDF basert på GDF-OWL
	- Lager først intern graf ved lesing og konvertering fra NVDB-API (nvdb2graph), eller fra ferdig fil.
	- Kjører et sett med SPARQL-spørringer for å konvertere til GDF, basert på linkset, tekstfil med SPARQL-spørringer og funksjonen sqFileProcess fra sparqlMapping.py. 
	- Denne kan gjøres mer generisk for oversetting til en hvilket som helst annen ontologi.

nvdb2AnyOtl.py
	- Konverterer fra RDF basert på NVDB-OWL til RDF basert på en annen ontologi
	- Lager først intern graf ved lesing og konvertering fra NVDB-API (nvdb2graph), eller fra ferdig fil.
	- Kjører et sett med SPARQL-spørringer for å konvertere til annen ontologi, basert på linkset, tekstfil med SPARQL-spørringer og funksjonen sqFileProcess fra sparqlMapping.py. 


sparqlMapping.py
	- Leser tekstfil med SPARQL-spørringer, og kjører dem sekvensielt
	- sqFile2Array: Leser SPARQL-queries fra fil til liste
	- sqFileProcess: Sekvensiell prosessering av queries fra fil
	
gdf.sparql
SPARQL-spørringer for konvertering fra NVDB til GDF![image](https://user-images.githubusercontent.com/7501876/124784438-38e26d00-df46-11eb-8fc4-b07e5b9edd06.png)
