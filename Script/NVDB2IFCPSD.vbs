option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre
'
' Script Name: NVDB2IFCPSD
' Author: Knut Jetlund
' Purpose: Generering av IFC PropertySetDefinitions (XML) pr vegobjekttype
' Date: 20220214
'

dim objFSO, objPSDFile
dim nvdb_navn, sosi_navn, definition
dim tV as EA.TaggedValue
dim atV as EA.AttributeTag
dim ctV as EA.ConnectorTag
dim conEnd as EA.ConnectorEnd
dim XMLstring 

Sub main

	'Vise og tøm scriptvinduer
	outputTabs
	'Kobler til modell og database
	connect2models

	'Hent NVDB-SOSI-modellen		
	set pkSOSINVDB = Repository.GetPackageByGuid(guidSOSIDatakatalog)
	Repository.WriteOutput "Script", Now & " Hovedpakke: " & pkSOSINVDB.Name & " (" & pkSOSINVDB.PackageGUID & ")", 0 
	For each pkOT in pkSOSINVDB.Packages
		Repository.WriteOutput "Script", Now & " ------------------------------------------------------------------------------", 0 
		Repository.WriteOutput "Script", Now & " Vegobjekttypepakke: " & pkOT.Name, 0 

		'--------------------------------------------------------------------------------------------
		'Lag strømmen som all tekst skal skrives til
		Set objFSO=CreateObject("Scripting.FileSystemObject")
		Set objPSDFile = CreateObject("ADODB.Stream")
		objPSDFile.CharSet = "utf-8"
		objPSDFile.Open
		objPSDFile.WriteText "<?xml version=""1.0"" encoding=""UTF-8""?>" & vbCrLf
		objPSDFile.WriteText "<PropertySetDef xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" " & vbCrLf
		objPSDFile.WriteText "  xsi:noNamespaceSchemaLocation=""http://standards.buildingsmart.org/IFC/RELEASE/IFC4/FINAL/PSD/PSD_IFC4.xsd""> " & vbCrLf
		objPSDFile.WriteText "  <IfcVersion/>" & vbCrLf
		'----------------------------------------------------------------------------------------------------------
		'Finn selve objekttypen
		for each element in pkOT.elements
			nvdb_navn = ""	
			set tagVal = element.TaggedValues.GetByName("NVDB_navn")
			if not tagVal is nothing then nvdb_navn=tagVal.Value
			If UCase(element.Stereotype)="FEATURETYPE" then
				'---------------------------------------------------------------------------------------------
				'Håndtering av vegobjekttyper (featuretypes)
				Repository.WriteOutput "Script", Now & " FeatureType: " & element.Name & " (" & nvdb_navn & ")", 0 
				sosi_navn = element.name		
				objPSDFile.WriteText "  <Name>Pset_NVDB_" & element.name & "</Name>" & vbCrLf
				
				XMLstring = element.Notes
				XMLstring = replace(XMLstring,"<","&lt;")
				XMLstring = replace(XMLstring,">","&gt;")
				objPSDFile.WriteText "  <Definition>" & XMLstring & "</Definition>" & vbCrLf

				objPSDFile.WriteText "  <Applicability/>" & vbCrLf
				objPSDFile.WriteText "  <ApplicableClasses/>" & vbCrLf
				objPSDFile.WriteText "  <ApplicableTypeValue/>" & vbCrLf

				objPSDFile.WriteText "  <PropertyDefs>" & vbCrLf
				'------------------------------------------------------------------------------------------------
				'Håndtering av attributter under vegobjekttypen som properties 
				For each eAttributt in element.Attributes
					'Skriver kun attributter som har alias, dvs de som ligger i original Datakatalog-database. Andre egenskaper, som lineærPosisjon osv, ligger i nvdb_core.ttl
					if eAttributt.Alias <> "" then
						Repository.WriteOutput "Script", Now & " Attributt: " & eAttributt.Name, 0 
						dim pType, range 
						pType = "d"
						range = ""
						dim gT 
						gT = false
						'------------------------------------------------------------------------------------------------
						'Konverteringsregler fra ISO/TC 211-datatyper og interne NVDB-datatyper til IFC-datatyper
						Select Case eAttributt.Type
							Case "CharacterString": 
								range = "IfcText"
							Case "Struktur": 
								'Forenkling for datatype "struktur".
								'Foreløpig brukt med for målinger og statistikk
								'TODO: Trenger en annen håndtering dersom den blir mer brukt
								range = "IfcText" 
							Case "Integer":
								range = "IfcInteger"							
							Case "Real":
								range = "IfcReal"
							Case "Date":
								range = "IfcDate"
							Case "Time":
								range = "IfcTime"
							Case "Boolean":
								range = "IfcBoolean"
							Case "BinærObjekt", "BinærObjekt, TSF", "BinærObjekt, Tekst", "BinærObjekt, Lyd"
								range = "IfcBinary"
								pType = "b"
								'Binærtyper tas ikke med, er ikke støtta i PSD.xml
							Case "Punkt", "Kurve", "Flate":
								'geometrityper --> tas ikke med i propertyset
								pType="g"
							case else
								'Attributter med kodeliste --> object properties med kodeliste som range
								pType = "o"
						End Select
						'---------------------------------------------------------------------------------------------
						'Skriver PropertyDef for attributter 
						if pType = "d" or pType = "o" then
							objPSDFile.WriteText "    <PropertyDef>" & vbCrLf
							objPSDFile.WriteText "      <Name>" & eAttributt.name & "</Name>" & vbCrLf
							if not eAttributt.Notes = "" then 
								XMLstring = eAttributt.Notes
								XMLstring = replace(XMLstring,"<","&lt;")
								XMLstring = replace(XMLstring,">","&gt;")
								objPSDFile.WriteText "      <Definition>" & XMLstring & "</Definition>"  & vbCrLf
							end if	
							
							if pType = "d" then
								'Enkel datatype = TypePropertySingleValue
								objPSDFile.WriteText "      <PropertyType>" & vbCrLf

								objPSDFile.WriteText "         <TypePropertySingleValue>" & vbCrLf
								objPSDFile.WriteText "             <DataType type=""" & range & """/>" & vbCrLf
								objPSDFile.WriteText "         </TypePropertySingleValue>" & vbCrLf
							elseif pType = "o" then
								'Kodeliste = TypePropertyEnumeratedValue
								objPSDFile.WriteText "      <PropertyType>" & vbCrLf
								dim klNavn
								klNavn = "PEnum_" & element.name & "_" & Ucase(Left(eAttributt.Name,1)) & mid(eAttributt.Name,2,len(eAttributt.Name)-1)
								
								'Finn kodeliste tilhørende egenskapstypen vha ClassifierID
								if eAttributt.ClassifierID <> 0 then
									set elementB= Repository.GetElementByID(eAttributt.ClassifierID)
									objPSDFile.WriteText "         <TypePropertyEnumeratedValue>" & vbCrLf
									objPSDFile.WriteText "             <EnumList name=""" & klNavn & """>" & vbCrLf
									'Loop for enumverdier
									dim enumItem as EA.Attribute
									for each enumItem in elementB.attributes
										XMLstring = enumItem.Name
										XMLstring = replace(XMLstring,"<","&lt;")
										XMLstring = replace(XMLstring,">","&gt;")
										objPSDFile.WriteText "                <EnumItem>" & XMLstring & "</EnumItem>" & vbCrLf								
									next
									objPSDFile.WriteText "             </EnumList>" & vbCrLf
									objPSDFile.WriteText "         </TypePropertyEnumeratedValue>" & vbCrLf
								end if	
							end if	
							objPSDFile.WriteText "      </PropertyType>" & vbCrLf				
							objPSDFile.WriteText "    </PropertyDef>" & vbCrLf
						end if	
					end if
				next	
				
				objPSDFile.WriteText "  </PropertyDefs>" & vbCrLf
			end if
		next 


		objPSDFile.WriteText "</PropertySetDef>" & vbCrLf


		'Skriv til fil 
		dim filetime
		filetime = replace(Now, ".","")
		filetime = replace(filetime, ":","")
		filetime = replace(filetime, " ","_")
		dim fname
		'fname = ifcPath & filetime & "PSD_NVDB_" & sosi_navn & ".xml"
		fname = ifcPath & "PSD_NVDB_" & sosi_navn & ".xml"
		Repository.WriteOutput "Script", Now & " Skriver til fil: " & fname & "...", 0 
		objPSDFile.SaveToFile fname, 2
		objPSDFile.Close
		
	Next
	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"


End Sub



main()