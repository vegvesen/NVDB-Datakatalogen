option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre
'
' Script Name: NVDB2OWL_1_Vegobjekttypekategorier
' Author: Knut Jetlund
' Purpose: Generering av ontologi som definerer vegobjekttypekategorier og koblingen til klasser, properties og instanser
' Date: 20210225
'

Dim rsVOTKategorier, rsVTKat, rsETKat, rsTVKat
dim objFSO, objOTLFile, objTemplate
dim nvdb_navn, definition
dim tV as EA.TaggedValue
dim atV as EA.AttributeTag
dim ctV as EA.ConnectorTag
dim conEnd as EA.ConnectorEnd

Sub main

	'Vise og tøm scriptvinduer
	outputTabs
	'Kobler til modell og database
	connect2models
	'Henter tabell for vegobjekttypekategorier
	set rsVOTKategorier = CreateObject("ADODB.Recordset")
	rsVOTKategorier.Open "SELECT * FROM VEGOB_TYPE_KAT", dbDakat, 3, 1
	rsVOTKategorier.Filter = "NAVN_VOBJ_TYP_KAT <> ""*Utgått*"""
	'Lager koblingstabell for vegobjekttyper og vegobjekttypekategorier	
	set rsVTKat = CreateObject("ADODB.Recordset")
	rsVTKat.Open "SELECT * FROM KOPL_VOT_KAT", dbDakat, 3, 1
	'rsVTKat.Filter = "Dato_fra <> NULL"
	'Lager koblingstabell for egenskapstyper og vegobjekttypekategorier	
	set rsETKat = CreateObject("ADODB.Recordset")
	rsETKat.Open "SELECT * FROM KOPL_ET_KAT", dbDakat, 3, 1
	'rsETKat.Filter = "Dato_fra <> NULL"
	'Lager koblingstabell for kodelisteverdier og vegobjekttypekategorier	
	set rsTVKat = CreateObject("ADODB.Recordset")
	rsTVKat.Open "SELECT * FROM KOPL_TV_KAT", dbDakat, 3, 1
	'rsTVKat.Filter = "Dato_fra <> NULL"
	
	'Hent NVDB-SOSI-modellen		
	set pkSOSINVDB = Repository.GetPackageByGuid(guidSOSIDatakatalog)
	Repository.WriteOutput "Script", Now & " Hovedpakke: " & pkSOSINVDB.Name & " (" & pkSOSINVDB.PackageGUID & ")", 0 
	
	'Lag strømmen som all tekst skal skrives til
	Set objFSO=CreateObject("Scripting.FileSystemObject")
	Set objOTLFile = CreateObject("ADODB.Stream")
	objOTLFile.CharSet = "utf-8"
	objOTLFile.Open

	'Lag heading med korrekt dato og versjon og til strømmen
	objOTLFile.WriteText "" & vbCrLf
	objOTLFile.WriteText "@prefix : <https://ontologi.atlas.vegvesen.no/nvdb/core/nvdb-owl#> ." & vbCrLf
	objOTLFile.WriteText "@prefix dc: <http://purl.org/dc/elements/1.1/> ." & vbCrLf
	objOTLFile.WriteText "@prefix lr: <http://www.roadotl.eu/iso19148/def/> ." & vbCrLf
	objOTLFile.WriteText "@prefix sf: <http://www.opengis.net/ont/sf#> ." & vbCrLf
	objOTLFile.WriteText "@prefix gsp: <http://www.opengis.net/ont/geosparql#> ." & vbCrLf
	objOTLFile.WriteText "@prefix owl: <http://www.w3.org/2002/07/owl#> ." & vbCrLf
	objOTLFile.WriteText "@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> ." & vbCrLf
	objOTLFile.WriteText "@prefix xml: <http://www.w3.org/XML/1998/namespace> ." & vbCrLf
	objOTLFile.WriteText "@prefix xsd: <http://www.w3.org/2001/XMLSchema#> ." & vbCrLf
	objOTLFile.WriteText "@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> ." & vbCrLf
	objOTLFile.WriteText "@prefix skos: <http://www.w3.org/2004/02/skos/core#> ." & vbCrLf
	objOTLFile.WriteText "@prefix dcterms: <http://purl.org/dc/terms/> ." & vbCrLf
	
	objOTLFile.WriteText vbCrLf
	objOTLFile.WriteText "<https://ontologi.atlas.vegvesen.no/nvdb/category/nvdb-kategorier> a owl:Ontology ;" & vbCrLf
	objOTLFile.WriteText "	owl:imports <http://www.w3.org/2004/02/skos/core> ;" & vbCrLf
	objOTLFile.WriteText "	owl:imports <https://ontologi.atlas.vegvesen.no/nvdb/core/nvdb-owl> ;" & vbCrLf
	objOTLFile.WriteText "	owl:versionInfo """ & FC_Version & """ ;" & vbCrLf
	objOTLFile.WriteText "	dc:creator :SVV ;" & vbCrLf
	objOTLFile.WriteText "	dc:date """ & left(Now,10) & """ ;" & vbCrLf
	objOTLFile.WriteText "	dc:description ""Ontologi for kategorisering av NVDB Datakatalogen""@no ;" & vbCrLf
	objOTLFile.WriteText "	dcterms:title ""NVDB Datakatalogen-kategorier versjon " & FC_version & """@no ;" & vbCrLf
	objOTLFile.WriteText "	dcterms:abstract ""Ontologi for kategorisering av klasser, properties og individer i Nasjonal Vegdatabank (NVDB)"" ." & vbCrLf
	objOTLFile.WriteText vbCrLf
	
	
	dim filetime
	filetime = replace(Now, ".","")
	filetime = replace(filetime, ":","")
	filetime = replace(filetime, " ","_")
	'objOTLFile.SaveToFile owlPath & "\" & filetime & "_nvdb-kategorier.ttl", 2
	'objOTLFile.Close
	'Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	'Repository.EnsureOutputVisible "Script"
	'exit sub

	'Løkke for alle vegobjektkategorier
	Do Until rsVOTKategorier.EOF
		'Lager OWL-klasse for vegobjekttypekategorien
		Repository.WriteOutput "Script", Now & " Vegobjekttypekategori: " & rsVOTKategorier.Fields("NAVN_VOBJ_TYP_KAT").Value & " (" & rsVOTKategorier.Fields("ID_VOBJ_TYP_KAT").Value & ")",0
		objOTLFile.WriteText "### " & owlURI & "#votkat" & rsVOTKategorier.Fields("ID_VOBJ_TYP_KAT").Value & vbCrLf
		objOTLFile.WriteText ":votkat" & rsVOTKategorier.Fields("ID_VOBJ_TYP_KAT").Value & " rdf:type owl:Class ;" & vbCrLf
		objOTLFile.WriteText "         rdfs:subClassOf :Vegobjekttypekategori ;" & vbCrLf
		objOTLFile.WriteText "         :nvdb_id " & rsVOTKategorier.Fields("ID_VOBJ_TYP_KAT").Value & " ;" & vbCrLf
		objOTLFile.WriteText "         :nvdb_navn """ & rsVOTKategorier.Fields("NAVN_VOBJ_TYP_KAT").Value & """@no ;" & vbCrLf					
		objOTLFile.WriteText "         rdfs:label """ & rsVOTKategorier.Fields("NAVN_VOBJ_TYP_KAT").Value & """@no ;" & vbCrLf					
		objOTLFile.WriteText "         skos:definition """ & rsVOTKategorier.Fields("BSKR_VOBJ_TYP_KAT").Value & """@no ." & vbCrLf
		objOTLFile.WriteText vbCrLf
		objOTLFile.WriteText vbCrLf
		rsVOTKategorier.MoveNext()
	Loop
	
	'Kjører gjennom alle pakker i NVDB-SOSI-modellen og skriver OWL-representasjon
	for each pkOT in pkSOSINVDB.Packages
		if pkOT.PackageGUID <> guidAbstrakteKlasser then 
			Repository.WriteOutput "Script", Now & " ------------------------------------------------------------------------------", 0 
			Repository.WriteOutput "Script", Now & " Vegobjekttypepakke: " & pkOT.Name, 0 
			'Løkke for alle elementer i pakken
			for each element in pkOT.elements
				nvdb_navn = ""	
				set tagVal = element.TaggedValues.GetByName("NVDB_navn")
				if not tagVal is nothing then nvdb_navn=tagVal.Value
				'Klasser i NVDB-SOSI-modellen er enten featuretype eller codelist. 
				If UCase(element.Stereotype)="FEATURETYPE" then
					'Håndtering av vegobjekttyper (featuretypes)
					Repository.WriteOutput "Script", Now & " FeatureType: " & element.Name & " (" & nvdb_navn & ")", 0 
					'Lager subclass-tilknytning til vegobjektkategorier ut fra filtrert recordset med koblingstabellen VOT-VOTKAT
					rsVTKat.Filter = "ID_VOBJ_TYPE = " & element.Alias
					if not(rsVTKat.BOF and rsVTKat.EOF) then
						'Skriver vegobjekttypen sin knytning til kategorier
						objOTLFile.WriteText "### " & owlURI & "#vot" & element.Alias & vbCrLf
						objOTLFile.WriteText ":vot" & element.Alias & " rdfs:subClassOf " & vbCrLf				
						do until rsVTKat.EOF
							Repository.WriteOutput "Script", Now & " Subklasse av vegobjekttypekategori :votkat" & rsVTKat.Fields("ID_VOBJ_TYP_KAT").Value, 0 
							objOTLFile.WriteText "						:votkat" & rsVTKat.Fields("ID_VOBJ_TYP_KAT").Value 
							rsVTKat.MoveNext()
							if rsVTKat.EOF then
								objOTLFile.WriteText " ." & vbCrLf
							else
								objOTLFile.WriteText " ," & vbCrLf
							end if
						loop		
					end if
					'Løkke for alle attributter under vegobjekttypen
					For each eAttributt in element.Attributes
						'Skriver kun attributter som har alias, dvs de som ligger i original Datakatalog-database. Andre egenskaper, som lineærPosisjon osv, ligger i nvdb_core.ttl
						if eAttributt.Alias <> "" then
							rsETKat.Filter = "ID_EGENSKAPSTYPE = " & eAttributt.Alias
							if not (rsETKat.BOF and rsETKat.EOF) then
								Repository.WriteOutput "Script", Now & " Attributt: " & eAttributt.Name, 0 
								objOTLFile.WriteText ":et" & eAttributt.Alias & " :medlem_av_VOTKategori " & vbCrLf
								'Kobler attributter (properties) og vegobjekttypekategorier ut fra filtrert koblingstabell
								do until rsETKat.EOF
									Repository.WriteOutput "Script", Now & " Attributten " & eAttributt.Name & " er medlem av vegobjekttypekategori :votkat" & rsETKat.Fields("ID_VOBJ_TYP_KAT").Value, 0 
									objOTLFile.WriteText "						:votkat" & rsETKat.Fields("ID_VOBJ_TYP_KAT").Value 
									rsETKat.MoveNext()
									if rsETKat.EOF then
										objOTLFile.WriteText " ." & vbCrLf
									else
										objOTLFile.WriteText " ," & vbCrLf
									end if
								loop
							end if
						end if
					next
				else
					'Håndtering av kodelister (codelist)
					rsETKat.Filter = "ID_EGENSKAPSTYPE = " & element.Alias
					if not (rsETKat.BOF and rsETKat.EOF) then 
						Repository.WriteOutput "Script", Now & " Kodeliste: " & element.Name & " (" & nvdb_navn & ")", 0 
						'Løkke for kodelisteverdier
						For each eAttributt in element.Attributes
						rsTVKat.Filter = "ID_TILLATT_VERDI = " & eAttributt.Alias
							if not (rsTVKat.BOF and rsTVKat.EOF) then 
								'Kobler kodelisteverdier (instanser) og vegobjekttypekategorier ut fra filtrert koblingstabell
								objOTLFile.WriteText ":tv" & eAttributt.Alias & " :medlem_av_VOTKategori " & vbCrLf
								do until rsTVKat.EOF
									Repository.WriteOutput "Script", Now & " Tillatt verdi " & eAttributt.Name & " er medlem av vegobjekttypekategori :votkat" & rsTVKat.Fields("ID_VOBJ_TYP_KAT").Value, 0 
									objOTLFile.WriteText "						:votkat" & rsTVKat.Fields("ID_VOBJ_TYP_KAT").Value 
									rsTVKat.MoveNext()
									if rsTVKat.EOF then
										objOTLFile.WriteText " ." & vbCrLf
									else
										objOTLFile.WriteText " ," & vbCrLf
									end if
								loop					
								objOTLFile.WriteText vbCrLf
							end if	
						Next				
					end if
				end if
			next
		end if	
		'Mulighet for å hoppe ut av løkka - fjernes når scriptet er ferdig.
		'dim msgAnsw
		'msgAnsw = MsgBox("Sjekk ttl-fila nå", vbOkCancel, "OWL")
		'if msgAnsw = 2 then
		'	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
		'	exit sub
		'end if	

	next
	
	'dim filetime
	filetime = replace(Now, ".","")
	filetime = replace(filetime, ":","")
	filetime = replace(filetime, " ","_")
	
	objOTLFile.SaveToFile owlPath & "\category\" & filetime & "_nvdb-kategorier.ttl", 2
	objOTLFile.Close
	
	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"



End Sub



main()