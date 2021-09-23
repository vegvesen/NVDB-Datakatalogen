option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre
'
' Script Name: NVDB2OWL_0_KunOTL
' Author: Knut Jetlund
' Purpose: Generering av OWL-OTL for komplett NVDB Datakatalog, uten kobling mellom vegobjekttyper og kategorier
' Date: 20210225
'

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

	'Hent NVDB-SOSI-modellen		
	set pkSOSINVDB = Repository.GetPackageByGuid(guidSOSIDatakatalog)
	Repository.WriteOutput "Script", Now & " Hovedpakke: " & pkSOSINVDB.Name & " (" & pkSOSINVDB.PackageGUID & ")", 0 
	
	'Lag strømmen som all tekst skal skrives til
	Set objFSO=CreateObject("Scripting.FileSystemObject")
	Set objOTLFile = CreateObject("ADODB.Stream")
	objOTLFile.CharSet = "utf-8"
	objOTLFile.Open

	'Les kjerneontologien nvdb_core.ttl
	Set objTemplate = CreateObject("ADODB.Stream")
	objTemplate.CharSet = "utf-8"
	objTemplate.Open
	objTemplate.LoadFromFile(owlPath & "\" & "nvdb_core.ttl")
	dim strTemplate
	strTemplate = objTemplate.ReadText()
	objTemplate.Close
	'Sett korrekt dato og versjon og skriv kjerneontologien til strømmen
	strTemplate = Replace(strTemplate,"dc:date ""yyyy-mm-dd""","dc:date """ & left(Now,10) & """")
	strTemplate = Replace(strTemplate,"dcterms:title ""NVDB Datakatalogen""","dcterms:title ""NVDB Datakatalogen" & " versjon " & FC_version & """")
	strTemplate = Replace(strTemplate,"owl:versionInfo ""n.mm""","owl:versionInfo """ & FC_version & """")
	objOTLFile.WriteText strTemplate & vbCrLf
	
	dim filetime
	filetime = replace(Now, ".","")
	filetime = replace(filetime, ":","")
	filetime = replace(filetime, " ","_")
	'objOTLFile.SaveToFile owlPath & "\" & filetime & "_nvdb-owl.ttl", 2
	'objOTLFile.Close
	'Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	'Repository.EnsureOutputVisible "Script"
	'exit sub

	dim strDjVOT
	strDjVOT = ":Vegobjekttype owl:disjointUnionOf (" & vbCrLf
	dim strDjKL
	strDjKL = ":Kodeliste owl:disjointUnionOf (" & vbCrLf
	dim strDjFtKl
	
	'Kjører gjennom alle pakker i NVDB-SOSI-modellen og skriver OWL-representasjon
	for each pkOT in pkSOSINVDB.Packages
		if pkOT.PackageGUID <> guidAbstrakteKlasser then 
			Repository.WriteOutput "Script", Now & " ------------------------------------------------------------------------------", 0 
			Repository.WriteOutput "Script", Now & " Vegobjekttypepakke: " & pkOT.Name, 0 
			'Løkke for alle elementer i pakken
			'----------------------------------------------------------------------------------- 
			'Fyll opp disjoint-strenger for vegobjekttyper og kodelister 
			strDjVOT = strDjVOT & "         :vot" & pkOT.Alias & vbCrLf
			strDjKL = strDjKL & "         :kl_vot" & pkOT.Alias & vbCrLf
			strDjFtKl = ":kl_vot" & pkOT.Alias & " owl:disjointUnionOf (" & vbCrLf
			for each element in pkOT.elements
				nvdb_navn = ""	
				set tagVal = element.TaggedValues.GetByName("NVDB_navn")
				if not tagVal is nothing then nvdb_navn=tagVal.Value
				'Klasser i NVDB-SOSI-modellen er enten featuretype eller codelist. 
				If UCase(element.Stereotype)="FEATURETYPE" then
					'Håndtering av vegobjekttyper (featuretypes)
					Repository.WriteOutput "Script", Now & " FeatureType: " & element.Name & " (" & nvdb_navn & ")", 0 
					

					'Skriver vegobjekttypen sin representasjon som OWL-klasse
					objOTLFile.WriteText "### " & owlURI & "#vot" & element.Alias & vbCrLf
					objOTLFile.WriteText ":vot" & element.Alias & " rdf:type owl:Class ;" & vbCrLf
					objOTLFile.WriteText "         rdfs:subClassOf :Vegobjekttype ;" & vbCrLf				
					objOTLFile.WriteText "         :nvdb_id " & element.Alias & " ;" & vbCrLf
					objOTLFile.WriteText "         :nvdb_navn """ & nvdb_navn & """@no ;" & vbCrLf					
					objOTLFile.WriteText "         rdfs:label """ & nvdb_navn & """@no ;" & vbCrLf					
					objOTLFile.WriteText "         :sosi_navn """ & element.Name & """@no ;" & vbCrLf
					'Angir om kjørefelt er relevant for denne vegobjekttypen
					set tV = element.TaggedValues.GetByName("KjorefeltRelevant")
					if not tV is nothing then 
						select case tV.Value
							case "0": objOTLFile.WriteText "         :kjørefeltRelevant ""Kan ikke gi feltkode.""@no ;" & vbCrLf										
							case "1": objOTLFile.WriteText "         :kjørefeltRelevant ""Kan gi feltkode.""@no ;" & vbCrLf																	
							case "2": objOTLFile.WriteText "         :kjørefeltRelevant ""Må gi feltkode.""@no ;" & vbCrLf										
						end select
					end if
					'Angir om sideposisjon er relevant for denne vegobjekttypen
					set tV = element.TaggedValues.GetByName("SideposisjonRelevant")
					if not tV is nothing then 
						select case tV.Value
							case "0": objOTLFile.WriteText "         :sideposisjonRelevant ""Kan ikke gi sideposisjon.""@no ;" & vbCrLf										
							case "1": objOTLFile.WriteText "         :sideposisjonRelevant ""Kan gi sideposisjon.""@no ;" & vbCrLf																	
							case "2": objOTLFile.WriteText "         :sideposisjonRelevant ""Må gi sideposisjon.""@no ;" & vbCrLf										
						end select
					end if
					'Angir om retning er relevant for denne vegobjekttypen
					set tV = element.TaggedValues.GetByName("RetningsRelevant")
					if not tV is nothing then 
						select case tV.Value
							case "J": objOTLFile.WriteText "         :retningRelevant ""Retningsrelevant.""@no ;" & vbCrLf										
							case "N": objOTLFile.WriteText "         :retningRelevant ""Ikke retningsrelevant.""@no ;" & vbCrLf																	
						end select
					end if
					'Angir type stedfesting vegnettet for denne vegobjekttypen
					set tV = element.TaggedValues.GetByName("Stedfesting")
					if not tV is nothing then 
						select case tV.Value
							case "punkt": objOTLFile.WriteText "         :stedfestingstype ""Punkt.""@no ;" & vbCrLf										
							case "strekning": objOTLFile.WriteText "         :stedfestingstype ""Strekning.""@no ;" & vbCrLf																	
						end select
					end if
					'Definisjon
					definition = replace(element.Notes, """","\""")
					definition = replace(definition, vbCrLf," ")
					objOTLFile.WriteText "         skos:definition """ & definition & """@no ." & vbCrLf				
					objOTLFile.WriteText vbCrLf
					objOTLFile.WriteText vbCrLf
					'Lager hovedklasse for kodelister tilhørende vegobjekttypen
					objOTLFile.WriteText "### " & owlURI & "#kl_vot" & pkOT.Alias & vbCrLf
					objOTLFile.WriteText ":kl_vot" & pkOT.Alias & " rdf:type owl:Class ;" & vbCrLf
					objOTLFile.WriteText "         rdfs:subClassOf :Kodeliste ;" & vbCrLf
					objOTLFile.WriteText "         rdfs:label ""Kodelister for " & nvdb_navn & """@no ;" & vbCrLf					
					objOTLFile.WriteText "         skos:definition ""Rotklasse for kodelister tilhørende vegobjekttypen " & nvdb_navn & """@no ." & vbCrLf
					objOTLFile.WriteText vbCrLf
					objOTLFile.WriteText vbCrLf
					'Lager hovedklasse for object properties tilhørende vegobjekttypen
					objOTLFile.WriteText "### " & owlURI & "#et_o_vot" & pkOT.Alias & vbCrLf
					objOTLFile.WriteText ":et_o_vot" & pkOT.Alias & " rdf:type owl:ObjectProperty ;" & vbCrLf
					objOTLFile.WriteText "         rdfs:subPropertyOf :vot_o_properties ;" & vbCrLf
					objOTLFile.WriteText "         rdfs:domain :vot" & element.Alias & ";" & vbCrLf
					objOTLFile.WriteText "         rdfs:label ""Object Properties for " & nvdb_navn & """@no ;" & vbCrLf					
					objOTLFile.WriteText "         skos:definition ""Rotklasse for object properties tilhørende vegobjekttypen " & nvdb_navn & """@no ." & vbCrLf
					objOTLFile.WriteText vbCrLf
					objOTLFile.WriteText vbCrLf
					'Lager hovedklasse for data properties tilhørende vegobjekttypen
					objOTLFile.WriteText "### " & owlURI & "#et_d_vot" & pkOT.Alias & vbCrLf
					objOTLFile.WriteText ":et_d_vot" & pkOT.Alias & " rdf:type owl:DatatypeProperty ;" & vbCrLf
					objOTLFile.WriteText "         rdfs:subPropertyOf :vot_d_properties ;" & vbCrLf
					objOTLFile.WriteText "         rdfs:domain :vot" & element.Alias & ";" & vbCrLf
					objOTLFile.WriteText "         rdfs:label ""Datatype Properties for " & nvdb_navn & """@no ;" & vbCrLf					
					objOTLFile.WriteText "         skos:definition ""Rotklasse for data properties tilhørende vegobjekttypen " & nvdb_navn & """@no ." & vbCrLf
					objOTLFile.WriteText vbCrLf
					objOTLFile.WriteText vbCrLf
				
					'Løkke for alle attributter under vegobjekttypen
					For each eAttributt in element.Attributes
						'Skriver kun attributter som har alias, dvs de som ligger i original Datakatalog-database. Andre egenskaper, som lineærPosisjon osv, ligger i nvdb_core.ttl
						if eAttributt.Alias <> "" then
							Repository.WriteOutput "Script", Now & " Attributt: " & eAttributt.Name, 0 
							dim pType, range 
							pType = "d"
							range = ""
							dim gT 
							gT = false
							'Konverteringsregler fra ISO/TC 211-datatyper og interne NVDB-datatyper til XSD-datatyper
							Select Case eAttributt.Type
								Case "CharacterString": 
									range = "xsd:string"
								Case "Struktur": 
									'Forenkling for datatype "struktur".
									'Foreløpig brukt med for målinger og statistikk
									'TODO: Trenger en annen håndtering dersom den blir mer brukt
									range = "xsd:string" 
								Case "Integer":
									range = "xsd:integer"							
								Case "Real":
									range = "xsd:double"
								Case "Date":
									range = "xsd:dateTime"
								Case "Boolean":
									range = "xsd:boolean"
								Case "BinærObjekt", "BinærObjekt, TSF", "BinærObjekt, Tekst", "BinærObjekt, Lyd"
									range = "xsd:base64Binary"
								Case "Punkt", "Kurve", "Flate":
									pType = "o"
									range = ":" & eAttributt.Type
									gT = true
							case else
								'Attributter med kodeliste --> object properties med kodeliste som range
								pType = "o"
								range = ":kl" & eAttributt.Alias
							End Select
							'NVDB-navn med håndtering av "fnutter"
							set aTag=eAttributt.TaggedValues.GetByName("NVDB_navn")
							nvdb_navn = ""
							if not aTag is nothing then nvdb_navn=aTag.Value
							nvdb_navn = Replace(nvdb_navn,"""","\""")

							'Lager enten data property eller object property av attributten
							objOTLFile.WriteText "### " & owlURI & "#et" & eAttributt.Alias & vbCrLf
							if pType = "d" then
								objOTLFile.WriteText ":et" & eAttributt.Alias & " rdf:type owl:DatatypeProperty ;" & vbCrLf
							else
								objOTLFile.WriteText ":et" & eAttributt.Alias & " rdf:type owl:ObjectProperty ;" & vbCrLf
							end if
							objOTLFile.WriteText "         rdfs:subPropertyOf :et_" & pType & "_vot" & pkOT.Alias & " ;" & vbCrLf
							'Attributte med geometridatatype --> subProperty av hasGeometry fra GeoSPARQL
							if gT then objOTLFile.WriteText "         rdfs:subPropertyOf gsp:hasGeometry ;" & vbCrLf
							
							'Domain og range for properties. 						
							objOTLFile.WriteText "         rdfs:domain :vot" & pkOT.Alias & ";" & vbCrLf
							objOTLFile.WriteText "         rdfs:range " & range & ";" & vbCrLf
							objOTLFile.WriteText "         :nvdb_id " & eAttributt.Alias & " ;" & vbCrLf
							objOTLFile.WriteText "         :nvdb_navn """ & nvdb_navn & """@no ;" & vbCrLf					
							objOTLFile.WriteText "         rdfs:label """ & nvdb_navn & """@no ;" & vbCrLf					
							objOTLFile.WriteText "         :sosi_navn """ & eAttributt.Name & """@no ;" & vbCrLf
							'Skriver viktighet for properties dersom angitt
							set atV = eAttributt.TaggedValues.GetByName("Viktighet")
							if not atV is nothing then objOTLFile.WriteText "         :viktighet """ & atV.Value & """@no ;" & vbCrLf																	
							'Skriver antall desimaler dersom angitt
							set atV = eAttributt.TaggedValues.GetByName("ANTALL_DESIMALER")
							if not atV is nothing then objOTLFile.WriteText "         :desimaler " & atV.Value & ";" & vbCrLf																	
							'Skriver enhet dersom angitt
							set atV = eAttributt.TaggedValues.GetByName("Enhet")
							if not atV is nothing then objOTLFile.WriteText "         :enhet """ & atV.Value & """@no ;" & vbCrLf																	
							'Skriver nivå av sensivitet dersom angitt
							set atV = eAttributt.TaggedValues.GetByName("Sensitiv")
							if not atV is nothing then objOTLFile.WriteText "         :sensitiv ""Tilgjengelig kun for UREG-brukere""@no ;" & vbCrLf
							'Håndtering av "fnutter" mm i definisjoner																						
							definition = replace(eAttributt.Notes, "\","\\")
							definition = replace(definition, """","\""")
							definition = replace(definition, vbCrLf," ")							
							objOTLFile.WriteText "         skos:definition """ & definition & """@no ." & vbCrLf					
							objOTLFile.WriteText vbCrLf
							objOTLFile.WriteText vbCrLf
							
							' ------------------------------------------------------
							'Knytt attributten til objekttypen som restriksjon
							objOTLFile.WriteText ":vot" & pkOT.Alias & " rdfs:subClassOf [ rdf:type owl:Restriction ;" & vbCrLf
							objOTLFile.WriteText "         owl:onProperty :et" & eAttributt.Alias & ";" & vbCrLf 	
							if pType = "d" then
								'Attributt uten kodeliste (dataproperty)
								objOTLFile.WriteText "         owl:onDataRange " & range & ";" & vbCrLf 		
							else
								'objectproperty
								objOTLFile.WriteText "         owl:onClass " & range & ";" & vbCrLf 		
							end if
							if eAttributt.LowerBound = 0 then 
								'Opsjonell attributt --> maks 1 (ingen multiple i NVDB)
								objOTLFile.WriteText "         owl:maxQualifiedCardinality ""1""^^xsd:nonNegativeInteger ;" & vbCrLf
							else
								'Påkrevd attributt --> eksakt 1 (ingen multiple i NVDB)
								'objOTLFile.WriteText "         owl:minQualifiedCardinality """ & eAttributt.LowerBound & """^^xsd:nonNegativeInteger ;" & vbCrLf
								'objOTLFile.WriteText "         owl:maxQualifiedCardinality """ & eAttributt.UpperBound & """^^xsd:nonNegativeInteger ;" & vbCrLf
								objOTLFile.WriteText "         owl:qualifiedCardinality ""1""^^xsd:nonNegativeInteger ;" & vbCrLf
							end if
							objOTLFile.WriteText "         ] ." & vbCrLf
							objOTLFile.WriteText ":vot" & pkOT.Alias & " rdfs:subClassOf [ rdf:type owl:Restriction ;" & vbCrLf
							objOTLFile.WriteText "         owl:onProperty :et" & eAttributt.Alias & ";" & vbCrLf 	
							objOTLFile.WriteText "         owl:allValuesFrom " & range & ";" & vbCrLf 	
							objOTLFile.WriteText "         ] ." & vbCrLf
							objOTLFile.WriteText vbCrLf
						end if	
					Next
					
					'Løkke for alle assosiasjoner for vegobjekttypen
					for each con in element.Connectors
						if (con.type = "Aggregation" or con.Type = "Association") then
							'Finner de to elementene (vegobjekttypene) som er involvert i assosiasjonen. elementA er aktuell vegobjekttype, elementB er den assosierte vegobjekttypen
							if con.ClientID = element.ElementID then
								set elementA = Repository.GetElementByID(con.ClientID)
								set elementB = Repository.GetElementByID(con.SupplierID)
								set conEnd = con.SupplierEnd
							else
								set elementB = Repository.GetElementByID(con.ClientID)
								set elementA = Repository.GetElementByID(con.SupplierID)
								set conEnd = con.ClientEnd
							end if
							
							'I SOSI-modellen er assosiasjoner angitt til de abstrakte klassene, mens i OWL skal de ligge direkte.
							'Finner derfor den ikke-abstrakte klassen (elementC) for assosiasjonen, for tagged values og korrekt navn
							dim spesCon as EA.Connector
							dim elementC as EA.Element
							for each spesCon in elementB.Connectors
								if (spesCon.type = "Generalization" or spesCon.Type = "Generalisation") then
									set elementC = Repository.GetElementByID(spesCon.ClientID)
								end if
							next
							
							'Skriver assosiasjonen som object property under hovedklassen for object properties for den aktuelle vegobjekttypen
							Repository.WriteOutput "Script", Now & " Assosiasjon: " & elementA.Name & " - " & elementC.Name, 0 
							objOTLFile.WriteText "### " & owlURI & "#as" & elementA.Alias & "_" & elementB.Alias & vbCrLf
							objOTLFile.WriteText ":as" & elementA.Alias & "_" & elementB.Alias & " rdf:type owl:ObjectProperty ;" & vbCrLf
							objOTLFile.WriteText "         rdfs:subPropertyOf :et_o_vot" & elementA.Alias & " ;" & vbCrLf
							'Domain og range for assosiasjonen
							objOTLFile.WriteText "         rdfs:domain :vot" & elementA.Alias & ";" & vbCrLf
							objOTLFile.WriteText "         rdfs:range :vot" & elementB.Alias & ";" & vbCrLf
							'NVDB-Id for assosiasjonen
							set ctV = con.TaggedValues.GetByName("NVDB_ID")
							if not ctV is nothing then objOTLFile.WriteText "         :nvdb_id " & ctV.Value & " ;" & vbCrLf
							'Beskrivelse av assosiasjonen, med korrekt navn på assosiert klasse (ikke den abstrakte)
							nvdb_navn = ""	
							set tagVal = elementC.TaggedValues.GetByName("NVDB_navn")
							if not tagVal is nothing then 
								nvdb_navn=tagVal.Value
								objOTLFile.WriteText "         rdfs:label ""Assosiert " & nvdb_navn & """@no ;" & vbCrLf
								objOTLFile.WriteText "         skos:definition ""Assosiasjon til " & nvdb_navn & """@no ;" & vbCrLf	
							end if	
							'SOSI-navn for assosiasjonen, ut fra rollenavn
							objOTLFile.WriteText "         :sosi_navn """ & conEnd.Role & """@no ;" & vbCrLf
							'Alle assosiasjoner settes som invers av den omvendte assosiasjonen
							objOTLFile.WriteText "         owl:inverseOf :as" & elementB.Alias & "_" & elementA.Alias & "."
							objOTLFile.WriteText vbCrLf
							objOTLFile.WriteText vbCrLf
							
							'-------------------------------------------------------
							'Knytt assosiasjonen til objekttypen som restriksjon
							objOTLFile.WriteText ":vot" & pkOT.Alias & " rdfs:subClassOf [ rdf:type owl:Restriction ;" & vbCrLf
							objOTLFile.WriteText "         owl:onProperty :as" & elementA.Alias & "_" & elementB.Alias & ";" & vbCrLf 	
							objOTLFile.WriteText "         owl:onClass :vot" & elementB.Alias & ";" & vbCrLf 		
							Select case conEnd.Cardinality
								case "1" or "1..1":
									objOTLFile.WriteText "       owl:qualifiedCardinality ""1""^^xsd:nonNegativeInteger ;" & vbCrLf 
								case "0..1":
									objOTLFile.WriteText "       owl:maxQualifiedCardinality ""1""^^xsd:nonNegativeInteger ;" & vbCrLf 
								case "1..*":
									objOTLFile.WriteText "       owl:minQualifiedCardinality ""1""^^xsd:nonNegativeInteger ;" & vbCrLf 	
							end select
							objOTLFile.WriteText "         ] ." & vbCrLf
							objOTLFile.WriteText ":vot" & pkOT.Alias & " rdfs:subClassOf [ rdf:type owl:Restriction ;" & vbCrLf
							objOTLFile.WriteText "         owl:onProperty :as" & elementA.Alias & "_" & elementB.Alias & ";" & vbCrLf 	
							objOTLFile.WriteText "         owl:allValuesFrom :vot" & elementB.Alias & ";" & vbCrLf 	
							objOTLFile.WriteText "         ] ." & vbCrLf
							objOTLFile.WriteText vbCrLf
						end if	
					next
				else
					'Håndtering av kodelister (codelist)
					Repository.WriteOutput "Script", Now & " Kodeliste: " & element.Name & " (" & nvdb_navn & ")", 0 
					'-------------------------------------------------------
					'Disjointstreng for kodelister under pakken
					strDjFtKl = strDjFtKl & "         :kl" & element.Alias & vbCrLf			
					
					'Skriver kodelisten som OWL-klasse som er subclass av hovedklassen for kodelister for den aktuelle vegobjekttypen 
					objOTLFile.WriteText "### " & owlURI & "#kl" & element.Alias & vbCrLf
					objOTLFile.WriteText ":kl" & element.Alias & " rdf:type owl:Class ;" & vbCrLf
					objOTLFile.WriteText "         rdfs:subClassOf :kl_vot" & pkOT.Alias & " ;" & vbCrLf
					objOTLFile.WriteText "         :nvdb_id " & element.Alias & " ;" & vbCrLf
					objOTLFile.WriteText "         :nvdb_navn """ & nvdb_navn & """@no ;" & vbCrLf					
					objOTLFile.WriteText "         rdfs:label """ & nvdb_navn & """@no ;" & vbCrLf					
					objOTLFile.WriteText "         :sosi_navn """ & element.Name & """@no ;" & vbCrLf
					'Håndtering av "fnutter" og linjeskift i definisjonen
					definition = replace(element.Notes, """","\""")
					definition = replace(definition, vbCrLf," ")			
					objOTLFile.WriteText "         skos:definition """ & definition & """@no ." & vbCrLf
					objOTLFile.WriteText vbCrLf
					objOTLFile.WriteText vbCrLf
					
					'Løkke for kodelisteverdier
					dim strClOneOf
					strClOneOf = ":kl" & element.Alias & " owl:oneOf (" & vbCrLf
					
					For each eAttributt in element.Attributes
						'---------------------------------------------
						'OneOf for kodelisteverdier
						strClOneOf = strClOneOf & "         :tv" & eAttributt.Alias & vbCrLf
					
						set aTag=eAttributt.TaggedValues.GetByName("NVDB_navn")
						nvdb_navn = ""
						if not aTag is nothing then nvdb_navn=aTag.Value
						nvdb_navn = Replace(nvdb_navn,"""","\""")
						'Skriver kodelisteverdiene som instanser av kodelisten 
						objOTLFile.WriteText "### " & owlURI & "#tv" & eAttributt.Alias & vbCrLf
						objOTLFile.WriteText ":tv" & eAttributt.Alias & " rdf:type :kl" & element.Alias & " ;" & vbCrLf
						objOTLFile.WriteText "         :nvdb_id " & eAttributt.Alias & " ;" & vbCrLf
						objOTLFile.WriteText "         :nvdb_navn """ & nvdb_navn & """@no ;" & vbCrLf					
						objOTLFile.WriteText "         rdfs:label """ & nvdb_navn & """@no ;" & vbCrLf					
						objOTLFile.WriteText "         :sosi_navn """ & Replace(eAttributt.Name,"""","\""") & """@no ;" & vbCrLf
												
						'Skriver kortnavn dersom dette er angitt
						if IsNull(eAttributt.Default) or eAttributt.Default = "" then
							Repository.WriteOutput "Script", Now & " Kodeverdi: " & eAttributt.Name, 0 
						else
							Repository.WriteOutput "Script", Now & " Kodeverdi: " & eAttributt.Name & " (" & eAttributt.Default & ")", 0 
							objOTLFile.WriteText "         :kortnavn """ & eAttributt.Default & """ ;" & vbCrLf
						end if
						'Håndtering av "fnutter" og linjeskift i definisjonen
						definition = replace(eAttributt.Notes, """","\""")
						definition = replace(definition, vbCrLf," ")	
						'Repository.WriteOutput "Endringer", Now & " Kodeverdi: " & eAttributt.Name & " Definisjon: " & definition, 0 
						
						objOTLFile.WriteText "         skos:definition """ & definition & """@no ." & vbCrLf
						objOTLFile.WriteText vbCrLf
						objOTLFile.WriteText vbCrLf
					Next	

					strClOneOf = strClOneOf & "    ) ; ." & vbCrLf
					objOTLFile.WriteText strClOneOf & vbCrLf			
				end if
			next
			strDjFtKl = strDjFtKl & "    ) ; ."
			objOTLFile.WriteText strDjFtKl & vbCrLf			
		end if
		
		'Mulighet for å hoppe ut av løkka - fjernes når scriptet er ferdig.
		'dim msgAnsw
		'msgAnsw = MsgBox("Sjekk ttl-fila nå", vbOkCancel, "OWL")
		'if msgAnsw = 2 then
		'	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
		'	exit sub
		'end if	

	next
	
	'Skriv disjoint-setninger
	strDjVOT = strDjVOT & "    ) ; ." & vbCrLf
	objOTLFile.WriteText strDjVOT & vbCrLf
	strDjKL = strDjKL & "    ) ; ." & vbCrLf
	objOTLFile.WriteText strDjKL & vbCrLf
	
	'dim filetime
	filetime = replace(Now, ".","")
	filetime = replace(filetime, ":","")
	filetime = replace(filetime, " ","_")
	
	objOTLFile.SaveToFile owlPath & "\" & filetime & "_nvdb-owl.ttl", 2
	objOTLFile.Close
	
	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"



End Sub



main()