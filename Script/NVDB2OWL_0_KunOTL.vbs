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

	'Vise og t�m scriptvinduer
	outputTabs
	'Kobler til modell og database
	connect2models

	'Hent NVDB-SOSI-modellen		
	set pkSOSINVDB = Repository.GetPackageByGuid(guidSOSIDatakatalog)
	Repository.WriteOutput "Script", Now & " Hovedpakke: " & pkSOSINVDB.Name & " (" & pkSOSINVDB.PackageGUID & ")", 0 
	'--------------------------------------------------------------------------------------------
	'Lag str�mmen som all tekst skal skrives til
	Set objFSO=CreateObject("Scripting.FileSystemObject")
	Set objOTLFile = CreateObject("ADODB.Stream")
	objOTLFile.CharSet = "utf-8"
	objOTLFile.Open
	'----------------------------------------------------------------------------------------------------------
	'Les kjerneontologien nvdb_core.ttl
	Set objTemplate = CreateObject("ADODB.Stream")
	objTemplate.CharSet = "utf-8"
	objTemplate.Open
	objTemplate.LoadFromFile(owlPath & "\core\" & "nvdb-core.ttl")
	dim strTemplate
	strTemplate = objTemplate.ReadText()
	objTemplate.Close
	'Sett korrekt dato og versjon og skriv kjerneontologien til str�mmen
	strTemplate = Replace(strTemplate,"dc:date ""2020-06-19""","dc:date """ & left(Now,10) & """")
	strTemplate = Replace(strTemplate,"dcterms:title ""NVDB Datakatalogen""","dcterms:title ""NVDB Datakatalogen" & " versjon " & FC_version & """")
	strTemplate = Replace(strTemplate,"owl:versionInfo ""n.mm""","owl:versionInfo """ & FC_version & """")
	objOTLFile.WriteText strTemplate & vbCrLf
	
	dim filetime
	'Repository.WriteOutput "Script", Now & " Skriver innledning til fil " & owlPath & "core\heading_nvdb-owl.ttl", 0 
	'objOTLFile.SaveToFile owlPath & "core\heading_nvdb-owl.ttl", 2
	'objOTLFile.Close
	'Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	'exit sub

	dim strDjVOT
	strDjVOT = ":Vegobjekttype owl:disjointUnionOf (" & vbCrLf
	dim strDjKL
	strDjKL = ":Kodeliste owl:disjointUnionOf (" & vbCrLf
	dim strDjFtKl
	
	'---------------------------------------------------------------------------------
	'Kj�rer gjennom alle pakker i NVDB-SOSI-modellen og skriver OWL-representasjon
	for each pkOT in pkSOSINVDB.Packages
		if pkOT.PackageGUID <> guidAbstrakteKlasser then 
			Repository.WriteOutput "Script", Now & " ------------------------------------------------------------------------------", 0 
			Repository.WriteOutput "Script", Now & " Vegobjekttypepakke: " & pkOT.Name, 0 
			'L�kke for alle elementer i pakken
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
					'---------------------------------------------------------------------------------------------
					'H�ndtering av vegobjekttyper (featuretypes)
					Repository.WriteOutput "Script", Now & " FeatureType: " & element.Name & " (" & nvdb_navn & ")", 0 
					

					'Skriver vegobjekttypen sin representasjon som OWL-klasse
					objOTLFile.WriteText "### " & owlURI & "#vot" & element.Alias & vbCrLf
					objOTLFile.WriteText ":vot" & element.Alias & " rdf:type owl:Class ;" & vbCrLf
					objOTLFile.WriteText "         rdfs:subClassOf :Vegobjekttype ;" & vbCrLf				
					objOTLFile.WriteText "         :nvdb_id " & element.Alias & " ;" & vbCrLf
					objOTLFile.WriteText "         :nvdb_navn """ & nvdb_navn & """@no ;" & vbCrLf					
					objOTLFile.WriteText "         rdfs:label """ & nvdb_navn & """@no ;" & vbCrLf					
					objOTLFile.WriteText "         :sosi_navn """ & element.Name & """@no ;" & vbCrLf
					'Angir om kj�refelt er relevant for denne vegobjekttypen
					set tV = element.TaggedValues.GetByName("KjorefeltRelevant")
					if not tV is nothing then 
						select case tV.Value
							case "0": objOTLFile.WriteText "         :kj�refeltRelevant ""Kan ikke gi feltkode.""@no ;" & vbCrLf										
							case "1": objOTLFile.WriteText "         :kj�refeltRelevant ""Kan gi feltkode.""@no ;" & vbCrLf																	
							case "2": objOTLFile.WriteText "         :kj�refeltRelevant ""M� gi feltkode.""@no ;" & vbCrLf										
						end select
					end if
					'Angir om sideposisjon er relevant for denne vegobjekttypen
					set tV = element.TaggedValues.GetByName("SideposisjonRelevant")
					if not tV is nothing then 
						select case tV.Value
							case "0": objOTLFile.WriteText "         :sideposisjonRelevant ""Kan ikke gi sideposisjon.""@no ;" & vbCrLf										
							case "1": objOTLFile.WriteText "         :sideposisjonRelevant ""Kan gi sideposisjon.""@no ;" & vbCrLf																	
							case "2": objOTLFile.WriteText "         :sideposisjonRelevant ""M� gi sideposisjon.""@no ;" & vbCrLf										
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
					'Lager hovedklasse for kodelister tilh�rende vegobjekttypen
					objOTLFile.WriteText "### " & owlURI & "#kl_vot" & pkOT.Alias & vbCrLf
					objOTLFile.WriteText ":kl_vot" & pkOT.Alias & " rdf:type owl:Class ;" & vbCrLf
					objOTLFile.WriteText "         rdfs:subClassOf :Kodeliste ;" & vbCrLf
					objOTLFile.WriteText "         rdfs:label ""Tillatt verdi for " & nvdb_navn & """@no ;" & vbCrLf					
					objOTLFile.WriteText "         skos:definition ""Rotklasse for kodelister tilh�rende vegobjekttypen " & nvdb_navn & """@no ." & vbCrLf
					objOTLFile.WriteText vbCrLf
					objOTLFile.WriteText vbCrLf
					'Lager hovedklasse for object properties tilh�rende vegobjekttypen
					objOTLFile.WriteText "### " & owlURI & "#et_o_vot" & pkOT.Alias & vbCrLf
					objOTLFile.WriteText ":et_o_vot" & pkOT.Alias & " rdf:type owl:ObjectProperty ;" & vbCrLf
					objOTLFile.WriteText "         rdfs:subPropertyOf :vot_o_properties ;" & vbCrLf
					objOTLFile.WriteText "         rdfs:domain :vot" & element.Alias & ";" & vbCrLf
					objOTLFile.WriteText "         rdfs:label ""Object property for " & nvdb_navn & """@no ;" & vbCrLf					
					objOTLFile.WriteText "         skos:definition ""Rotklasse for object properties tilh�rende vegobjekttypen " & nvdb_navn & """@no ." & vbCrLf
					objOTLFile.WriteText vbCrLf
					objOTLFile.WriteText vbCrLf
					'Lager hovedklasse for data properties tilh�rende vegobjekttypen
					objOTLFile.WriteText "### " & owlURI & "#et_d_vot" & pkOT.Alias & vbCrLf
					objOTLFile.WriteText ":et_d_vot" & pkOT.Alias & " rdf:type owl:DatatypeProperty ;" & vbCrLf
					objOTLFile.WriteText "         rdfs:subPropertyOf :vot_d_properties ;" & vbCrLf
					objOTLFile.WriteText "         rdfs:domain :vot" & element.Alias & ";" & vbCrLf
					objOTLFile.WriteText "         rdfs:label ""Data property for " & nvdb_navn & """@no ;" & vbCrLf					
					objOTLFile.WriteText "         skos:definition ""Rotklasse for data properties tilh�rende vegobjekttypen " & nvdb_navn & """@no ." & vbCrLf
					objOTLFile.WriteText vbCrLf
					objOTLFile.WriteText vbCrLf
				
					'------------------------------------------------------------------------------------------------
					'H�ndtering av attributter under vegobjekttypen som properties 
					For each eAttributt in element.Attributes
						'Skriver kun attributter som har alias, dvs de som ligger i original Datakatalog-database. Andre egenskaper, som line�rPosisjon osv, ligger i nvdb_core.ttl
						if eAttributt.Alias <> "" then
							Repository.WriteOutput "Script", Now & " Attributt: " & eAttributt.Name, 0 
							dim pType, range 
							pType = "d"
							range = ""
							dim gT 
							gT = false
							'------------------------------------------------------------------------------------------------
							'Konverteringsregler fra ISO/TC 211-datatyper og interne NVDB-datatyper til XSD-datatyper
							Select Case eAttributt.Type
								Case "CharacterString": 
									range = "xsd:string"
								Case "Struktur": 
									'Forenkling for datatype "struktur".
									'Forel�pig brukt med for m�linger og statistikk
									'TODO: Trenger en annen h�ndtering dersom den blir mer brukt
									range = "xsd:string" 
								Case "Integer":
									range = "xsd:integer"							
								Case "Real":
									range = "xsd:double"
								Case "Date":
									range = "xsd:Date"
								Case "Time":
									range = "xsd:Time"							
								Case "Boolean":
									range = "xsd:boolean"
								Case "Bin�rObjekt", "Bin�rObjekt, TSF", "Bin�rObjekt, Tekst", "Bin�rObjekt, Lyd"
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
							'NVDB-navn med h�ndtering av "fnutter"
							set aTag=eAttributt.TaggedValues.GetByName("NVDB_navn")
							nvdb_navn = ""
							if not aTag is nothing then nvdb_navn=aTag.Value
							nvdb_navn = Replace(nvdb_navn,"""","\""")
							
							'-----------------------------------------------------------------------------------------------			
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
							'--------------------------------------------------------------------------------------------
							'Domain og range for properties. 						
							objOTLFile.WriteText "         rdfs:domain :vot" & pkOT.Alias & ";" & vbCrLf
							objOTLFile.WriteText "         rdfs:range " & range & ";" & vbCrLf
							'Alle properties i NVDB har maksimal mulitplisitet 1 --> FunctionalProperty (FunctionalDataProperty eller FunctionalObjectProperty)
							objOTLFile.WriteText "         rdf:type owl:FunctionalProperty;" & vbCrLf
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
							'Skriver niv� av sensivitet dersom angitt
							set atV = eAttributt.TaggedValues.GetByName("Sensitiv")
							if not atV is nothing then objOTLFile.WriteText "         :sensitiv ""Tilgjengelig kun for UREG-brukere""@no ;" & vbCrLf
							'H�ndtering av "fnutter" mm i definisjoner																						
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
								'P�krevd attributt --> eksakt 1 (ingen multiple i NVDB)
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
					
					'----------------------------------------------------------------------------------------------------------------
					'L�kke for alle assosiasjoner for vegobjekttypen
					for each con in element.Connectors
						if (con.type = "Aggregation" or con.Type = "Association") then
							'-------------------------------------------------------------------------------------------------
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
							
							'---------------------------------------------------------------------------------------------
							'H�ndtering av abstrakte klasser
							'I SOSI-modellen er assosiasjoner angitt fra den enkelte klassen til en abstrakt klasse over den egentlige assosie klassen av hensyn til lasting av XML-skjema
							'I OWL skal assosiasjonene ligge som properties mellom de konkrete klassene, 
							'Finner derfor den ikke-abstrakte klassen (elementC) for assosiasjonen, der tagged values og korrekt navn finnes
							dim spesCon as EA.Connector
							dim elementC as EA.Element
							for each spesCon in elementB.Connectors
								if (spesCon.type = "Generalization" or spesCon.Type = "Generalisation") then
									set elementC = Repository.GetElementByID(spesCon.ClientID)
								end if
							next
							
							'--------------------------------------------------------------------------------------------------------
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
							'Beskrivelse av assosiasjonen, med korrekt navn p� assosiert klasse (ikke den abstrakte)
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
							'Knytter assosiasjonen til objekttypen som restriksjon
							'Finner kardinalitet
							dim crdArr
							crdArr = split(conEnd.Cardinality,"..")
							dim lower, upper
							lower = crdArr(0)
							if Ubound(crdArr) = 0 then upper = lower else upper = crdArr(1)				
							if conEnd.Cardinality <> "0..*" then 'Ingen krav til kardinalitet ved 0..*
								objOTLFile.WriteText ":vot" & pkOT.Alias & " rdfs:subClassOf [ rdf:type owl:Restriction ;" & vbCrLf
								objOTLFile.WriteText "         owl:onProperty :as" & elementA.Alias & "_" & elementB.Alias & ";" & vbCrLf 	
								objOTLFile.WriteText "         owl:onClass :vot" & elementB.Alias & ";" & vbCrLf 	
								'Eksakt kardinalitet 1..1 eller lignende	
								if lower = upper then 
									objOTLFile.WriteText "       owl:qualifiedCardinality """ & lower & """^^xsd:nonNegativeInteger ;" & vbCrLf 
								else	
									'Krav til minimum, ikke eksakt
									if lower <> "0" then objOTLFile.WriteText "       owl:minQualifiedCardinality """ & lower & """^^xsd:nonNegativeInteger ;" & vbCrLf 	
									'Begrensning p� maksimum, ikke eksakt
									if upper <> "*" then objOTLFile.WriteText "       owl:maxQualifiedCardinality """ & upper & """^^xsd:nonNegativeInteger ;" & vbCrLf 	
								end if

								objOTLFile.WriteText "         ] ." & vbCrLf
							end if	
							objOTLFile.WriteText ":vot" & pkOT.Alias & " rdfs:subClassOf [ rdf:type owl:Restriction ;" & vbCrLf
							objOTLFile.WriteText "         owl:onProperty :as" & elementA.Alias & "_" & elementB.Alias & ";" & vbCrLf 	
							objOTLFile.WriteText "         owl:allValuesFrom :vot" & elementB.Alias & ";" & vbCrLf 	
							objOTLFile.WriteText "         ] ." & vbCrLf
							objOTLFile.WriteText vbCrLf
						end if	
					next
				else
					'---------------------------------------------------------------------------
					'H�ndtering av kodelister (codelist)
					Repository.WriteOutput "Script", Now & " Kodeliste: " & element.Name & " (" & nvdb_navn & ")", 0 
					'-------------------------------------------------------
					'Disjointstreng for kodelister under pakken
					strDjFtKl = strDjFtKl & "         :kl" & element.Alias & vbCrLf			
					'-----------------------------------------------------------------------
					'Skriver kodelisten som OWL-klasse som er subclass av hovedklassen for kodelister for den aktuelle vegobjekttypen 
					objOTLFile.WriteText "### " & owlURI & "#kl" & element.Alias & vbCrLf
					objOTLFile.WriteText ":kl" & element.Alias & " rdf:type owl:Class ;" & vbCrLf
					objOTLFile.WriteText "         rdfs:subClassOf :kl_vot" & pkOT.Alias & " ;" & vbCrLf
					objOTLFile.WriteText "         :nvdb_id " & element.Alias & " ;" & vbCrLf
					objOTLFile.WriteText "         :nvdb_navn """ & nvdb_navn & """@no ;" & vbCrLf					
					objOTLFile.WriteText "         rdfs:label """ & nvdb_navn & " (" & pkOT.Name & ")" & """@no ;" & vbCrLf					
					objOTLFile.WriteText "         :sosi_navn """ & element.Name & """@no ;" & vbCrLf
					'H�ndtering av "fnutter" og linjeskift i definisjonen
					definition = replace(element.Notes, """","\""")
					definition = replace(definition, vbCrLf," ")			
					objOTLFile.WriteText "         skos:definition """ & definition & """@no ." & vbCrLf
					objOTLFile.WriteText vbCrLf
					
					'---------------------------------------------------------------------------------------------------------
					'Lag concept schemes for kodelisten
					objOTLFile.WriteText "### " & owlURI & "#kl" & element.Alias & "CS" & vbCrLf
					objOTLFile.WriteText ":kl" & element.Alias & "CS a skos:ConceptScheme ;" & vbCrLf		
					objOTLFile.WriteText "         rdfs:label ""Konseptskjema " & nvdb_navn & " (" & pkOT.Name & ")" & """@no ;" & vbCrLf					
					objOTLFile.WriteText "         skos:definition """ & definition & """@no ;" & vbCrLf
					objOTLFile.WriteText "       dc:isFormatOf :kl" & element.Alias & " ." & vbCrLf
					objOTLFile.WriteText vbCrLf
					
					'----------------------------------------------------------------------------------------
					'H�ndtering av kodelisteverdier
					dim strClOneOf
					strClOneOf = ":kl" & element.Alias & " owl:oneOf (" & vbCrLf
					
					For each eAttributt in element.Attributes
						'---------------------------------------------
						'OneOf-setning for kodelisteverdier
						strClOneOf = strClOneOf & "         :tv" & eAttributt.Alias & vbCrLf
						'----------------------------------------------------------------------------------
						'Skriver kodelisteverdiene som instanser av kodelisten og som konsept
						set aTag=eAttributt.TaggedValues.GetByName("NVDB_navn")
						nvdb_navn = ""
						if not aTag is nothing then nvdb_navn=aTag.Value
						nvdb_navn = Replace(nvdb_navn,"""","\""")
						objOTLFile.WriteText "### " & owlURI & "#tv" & eAttributt.Alias & vbCrLf
						objOTLFile.WriteText ":tv" & eAttributt.Alias & " rdf:type :kl" & element.Alias & ", skos:Concept ;" & vbCrLf
						objOTLFile.WriteText "         skos:inScheme :kl" &  element.Alias & "CS ;" & vbCrLf					
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
						'H�ndtering av "fnutter" og linjeskift i definisjonen
						definition = replace(eAttributt.Notes, """","\""")
						definition = replace(definition, vbCrLf," ")	
						definition = replace(definition, vbCr," ")	
						definition = replace(definition, vbLf," ")	
						'Repository.WriteOutput "Endringer", Now & " Kodeverdi: " & eAttributt.Name & " Definisjon: " & definition, 0 
						objOTLFile.WriteText "         skos:definition """ & definition & """@no ." & vbCrLf
						objOTLFile.WriteText vbCrLf
						objOTLFile.WriteText vbCrLf
					Next	
					'-------------------------------------------------------------------------------------------
					'Fullf�rer oneof-setning for kodelister i pakken 
					strClOneOf = strClOneOf & "    ) ; ." & vbCrLf
					objOTLFile.WriteText strClOneOf & vbCrLf			
				end if
			next
			'---------------------------------------------------------------------------------------
			'Fullf�rer disjontsetning for kodelistepakker
			strDjFtKl = strDjFtKl & "    ) ; ."
			objOTLFile.WriteText strDjFtKl & vbCrLf			
		end if
		
		'Mulighet for � hoppe ut av l�kka - fjernes n�r scriptet er ferdig.
		'dim msgAnsw
		'msgAnsw = MsgBox("Sjekk ttl-fila n�", vbOkCancel, "OWL")
		'if msgAnsw = 2 then
		'	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
		'	exit sub
		'end if	

	next
	'----------------------------------------------------------------------------
	'Skriv disjoint-setninger p� �verste niv� 
	strDjVOT = strDjVOT & "    ) ; ." & vbCrLf
	objOTLFile.WriteText strDjVOT & vbCrLf
	strDjKL = strDjKL & "    ) ; ." & vbCrLf
	objOTLFile.WriteText strDjKL & vbCrLf
	
	'--------------------------------------------------------------------------------
	'Skriv til fil 
	'dim filetime
	filetime = replace(Now, ".","")
	filetime = replace(filetime, ":","")
	filetime = replace(filetime, " ","_")
	objOTLFile.SaveToFile owlPath & "\core\" & filetime & "_nvdb-owl.ttl", 2
	objOTLFile.Close
	
	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"

End Sub



main()