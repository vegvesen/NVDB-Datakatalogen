'option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre

' Script Name: DakatUML2SOSI2GML_0_Fellesskjema
' Author: Knut Jetlund
' Purpose: Generer applikasjonsskjema for SOSI-Fellesegenskaper og abstrakte klasser
' Date: 20200604
'
' NOTE: Requires a package to be selected in the Project Browser
' 
dim scRep as EA.Repository
dim scMod as EA.Package
dim scPck as EA.Package
dim pI as EA.Project					
dim objFS
dim lstTags
dim absClasses as EA.Package

sub createSCmodel(newOrCopy)
'Lager eller kobler til ShapeChange-EA-prosjekt og modell
	Repository.WriteOutput "Script", Now & " Lager ShapeChange-prosjektet " & scPath & "\" & scProject, 0 
	'Sletter eventuelt gammel fil
	If objFS.FileExists(scPath & "\" & scProject) then objFS.DeleteFile scPath & "\" & scProject, true
	'msgAnsw = MsgBox("Sjekk SC-modellen nå", vbOkCancel, "GML-applikasjonsskjema")

	set scRep = CreateObject("EA.Repository")

	if newOrCopy = "copy" then
		'Copy template project
		objFS.CopyFile scPath & "\" & scTemplate, scPath & "\" & scProject
	else 
		'Create and connect to model. 
		scRep.CreateModel cmEAPFromBase, scPath & "\" & scProject,1
	end if

	scRep.OpenFile(scPath & "\" & scProject)
	set pI = scRep.GetProjectInterface()
		
	'Lager eller kobler til basismodell og hovedpakker
	if newOrCopy = "copy" then
		set scMod = scRep.Models.GetByName("ShapeChange")
		if scMod is Nothing then 
			Repository.WriteOutput "Script", Now & " Finner ikke basismodellen ShapeChange", 0 
			exit sub
		end if	
		set scPck = scMod.Packages.GetByName("NVDB")
		if scPck is Nothing then 
			Repository.WriteOutput "Script", Now & " Finner ikke hovedpakken NVDB", 0 
			exit sub
		end if	
		set pkSOSIfelles = scPck.Packages.GetByName("SOSI Fellesegenskaper")
		if not pkSOSIfelles is nothing then
			Repository.WriteOutput "Script", Now & " Pakken SOSI Fellesegenskaper er funnet i prosjektet (" & pkSOSIfelles.PackageGUID & ")", 0 
		else
			Repository.WriteOutput "Script", Now & " Finner ikke pakken SOSI Fellesegenskaper", 0 
			scRep.Exit
			exit sub
		end if 
		set absClasses = scRep.GetPackageByGuid(guidAbstrakteKlasser)  ' scPck.Packages.GetByName("_AbstrakteKlasser")
		if not absClasses is nothing then
			Repository.WriteOutput "Script", Now & " Pakken med abstrakte klasser er funnet i prosjektet (" & absClasses.PackageGUID & ")", 0 
		else
			Repository.WriteOutput "Script", Now & " Finner ikke pakken _AbstrakteKlasser", 0 
			scRep.Exit
			exit sub
		end if	
	else
		Repository.WriteOutput "Script", Now & " Lager modellen ShapeChange", 0 
		set scMod = scRep.Models.AddNew("ShapeChange","")
		scMod.Update	
		scRep.Models.Refresh	
	
		'Lager hovedpakke i modellen ShapeChange
		Repository.WriteOutput "Script", Now & " Lager hovedpakke NVDB", 0 
		set scPck = scMod.Packages.AddNew("NVDB","")
		scPck.Update
		scMod.Packages.Refresh
		scPck.StereotypeEx="applicationSchema"
		scPck.Update
		'Importerer SOSI Fellesegenskaper-pakken til modellen ShapeChange
		importSOSIFelles
		'Importerer Abstrakte klasser-pakken til modellen ShapeChange
		importAbstrakteKlasser
	end if 	
		
	'Legger på GML-tagger på hovedpakka. Litt komplekst pga tagger både i og utenfor profil
	dim tagVal as EA.TaggedValue
	dim tagFound
	for idxT = 0 to lstTags.Count - 1
		dim tName
		tName = lstTags.GetKey(idxT)
		dim tValue
		tValue = lstTags.GetByIndex(idxT)

		tagFound = false
		for each tagVal in scPck.Element.TaggedValues
			if tagVal.Name = tName then 
				tagVal.Value = tValue
				tagVal.Update
				tagFound= true
				Repository.WriteOutput "Script", Now & " Fant tagged value " & tagVal.Name & " = " & tagVal.Value, 0 
			end if
		next
		if not tagFound then 
			Repository.WriteOutput "Script", Now & " Mangler tag " & tName, 0 
			set tagVal = scPck.Element.TaggedValues.AddNew(tName, tValue)
			tagVal.Update
		end if
	next
	scPck.Element.TaggedValues.Refresh
	for each tagVal in scPck.Element.TaggedValues
		Repository.WriteOutput "Script", Now & " Tagged value " & tagVal.Name & " = " & tagVal.Value, 0 
	next

	scPck.Element.TaggedValues.Refresh
	scMod.Packages.Refresh	
end sub

sub importSOSIFelles
	'Importerer SOSI Fellesegenskaper-pakken til modellen ShapeChange
	Repository.WriteOutput "Script", Now & " Importerer pakken SOSI Fellesegenskaper", 0 
	set pI = scRep.GetProjectInterface()
	pI.ImportPackageXMI scPck.PackageGUID, sosiPath & "\SOSI Fellesegenskaper.xml", 1,0
			
	'Finn SOSI Fellesegenskaper og sett GML-tagger
	set pkSOSIfelles = scPck.Packages.GetByName("SOSI Fellesegenskaper")
	if not pkSOSIfelles is nothing then
		Repository.WriteOutput "Script", Now & " Pakken SOSI Fellesegenskaper er funnet i prosjektet (" & pkSOSIfelles.PackageGUID & ")", 0 
		'Setter GML-tagger på SOSI Fellesegenskaper
		set tagVal = pkSOSIfelles.Element.TaggedValues.AddNew("version", FC_version)
		tagVal.Update
		set tagVal = pkSOSIfelles.Element.TaggedValues.AddNew("xmlns", "nvdb")
		tagVal.Update
		set tagVal = pkSOSIfelles.Element.TaggedValues.AddNew("xsdDocument", "SOSIFelles.xsd")
		tagVal.Update				
		set tagVal = pkSOSIfelles.Element.TaggedValues.AddNew("xsdEncodingRule", "sosi")
		tagVal.Update
		scMod.Packages.Refresh		
	else
		Repository.WriteOutput "Script", Now & " Finner ikke pakken SOSI Fellesegenskaper", 0 
		scRep.Exit
		exit sub
	end if	
end sub

sub importAbstrakteKlasser
	'Importerer Abstrakte klasser-pakken til modellen ShapeChange
	Repository.WriteOutput "Script", Now & " Importerer pakken med abstrakte NVDB-klasser", 0 
	set pI = scRep.GetProjectInterface()
	pI.ImportPackageXMI scPck.PackageGUID, sosiPath & "\_AbstrakteKlasser.xml", 1,0
			
	'Finn pakken for abstrakte klasser og sett GML-tagger
	set absClasses = scRep.GetPackageByGuid(guidAbstrakteKlasser)  ' scPck.Packages.GetByName("_AbstrakteKlasser")
	if not absClasses is nothing then
		Repository.WriteOutput "Script", Now & " Pakken med abstrakte klasser er funnet i prosjektet (" & absClasses.PackageGUID & ")", 0 
		'Setter GML-tagger på SOSI Fellesegenskaper
	'	set tagVal = absClasses.Element.TaggedValues.AddNew("version", FC_version)
	'	tagVal.Update
	'	set tagVal = absClasses.Element.TaggedValues.AddNew("xmlns", "nvdb")
	'	tagVal.Update
		'set tagVal = absClasses.Element.TaggedValues.AddNew("xsdDocument", "abstraktNVDB.xsd")
		'tagVal.Update				
	'	set tagVal = absClasses.Element.TaggedValues.AddNew("xsdEncodingRule", "sosi")
	'	tagVal.Update
	
		'Fjerner alle tagged values på pakka
		for idxT = 0 to absClasses.Element.TaggedValues.Count - 1
			absClasses.Element.TaggedValues.DeleteAt idxT, false
		next
		absClasses.Element.TaggedValues.Refresh
		scMod.Packages.Refresh		
	else
		Repository.WriteOutput "Script", Now & " Finner ikke pakken _AbstrakteKlasser", 0 
		scRep.Exit
		exit sub
	end if	
end sub

sub roleTags(e)
	'rydder opp i role tags
	Dim rTag As EA.RoleTag
	dim rTagFound
	Repository.WriteOutput "Script", Now & " Rydder i role tags ", 0 			
	for each con in e.Connectors
		rTagFound = false
		for idxT = 0 to con.ClientEnd.TaggedValues.Count - 1
			set rTag = con.ClientEnd.TaggedValues.GetAt(idxT)
			'Repository.WriteOutput "Script", Now & " Client End Role Tag: " & rTag.Tag & " (" & rTag.Value & ")", 0
			if rTag.Tag = "inlineOrByReference" and not rTagFound then
				rTag.Value = "ByReference"
				rTag.Update
				rTagFound = true
			elseif rTagFound then
				Repository.WriteOutput "Script", Now & " Sletter den duplikate taggen " & rTag.Tag  & " (" & rTag.Value & ")", 0
				con.ClientEnd.TaggedValues.DeleteAt idxT, false
			end  if
		next
		con.ClientEnd.TaggedValues.Refresh()
		con.ClientEnd.Update()

		rTagFound = false
		for idxT = 0 to con.SupplierEnd.TaggedValues.Count - 1
			set rTag = con.SupplierEnd.TaggedValues.GetAt(idxT)
			'Repository.WriteOutput "Script", Now & " Supplier End Role Tag: " & rTag.Tag & " (" & rTag.Value & ")", 0
			if rTag.Tag = "inlineOrByReference" and not rTagFound then
				rTag.Value = "ByReference"
				rTag.Update
				rTagFound = true
			elseif rTagFound then
				Repository.WriteOutput "Script", Now & " Sletter den duplikate taggen " & rTag.Tag  & " (" & rTag.Value & ")", 0
				con.SupplierEnd.TaggedValues.DeleteAt idxT, false
			end  if
		next
		con.SupplierEnd.TaggedValues.Refresh()
		con.SupplierEnd.Update()
	next
end sub

sub runSC
	'Kjører ShapeChange, venter på fullføring
	Repository.WriteOutput "Script", Now & " Kjører ShapeChange...", 0 
	dim strLine
	strLine = """C:\Program Files (x86)\AdoptOpenJDK\jre-14.0.1.7-hotspot\bin\java.exe"" -Xms256m -Xmx1024m -Dfile.encoding=UTF-8 -jar "
	strLine = strLine & """C:\DATA\Programvare\ShapeChange-2.9.1\ShapeChange-2.9.1.jar"" -c ""C:\DATA\GitHub\vegvesen\NVDB-Datakatalogen\SC\config\ShapeChangeConfiguration.xml"""
	dim shell
	set shell=createobject("wscript.shell") 
	shell.run strLine, 1, true
	set shell=nothing	
end sub

sub movefile(strFileName, strOldPath, strNewPath)
'Flytter angitt fil fra et område til et annet
	if objFS.FileExists(strNewPath & strFileName) then
		Repository.WriteOutput "Script", Now & " Filen " & strNewPath & strFileName & " finnes fra før slettes", 0 
		objFS.DeleteFile strNewPath & strFileName
	else
		'Repository.WriteOutput "Script", Now & " Filen finnes ikke fra før", 0 
	end if
	if objFS.FileExists(strOldPath & strFileName) then
		Repository.WriteOutput "Script", Now & " Flytter " & strOldPath & strFileName & " til " & strNewPath, 0 
		objFS.MoveFile strOldPath & strFileName, strNewPath
	else
		Repository.WriteOutput "Error", Now & " Filen " &  strOldPath & strFileName & " finnes ikke", 0 
	end if
end sub

sub Fellesskjema()

	dim msgAnsw
	dim pck as EA.Package

	' Show and clear the script output window
	Repository.EnsureOutputVisible "Script"
	Repository.ClearOutput "Script"
	Repository.CreateOutputTab "Error"
	Repository.ClearOutput "Error"

	' Get the currently selected package in the tree to work on
	dim thePackage as EA.Package
	set thePackage = Repository.GetTreeSelectedPackage()
	Set objFS = CreateObject("Scripting.FileSystemObject")
		
	if not thePackage is nothing and thePackage.ParentID <> 0 then
		Repository.WriteOutput "Script", Now & " Hovedpakke: " & thePackage.Name & " (" & thePackage.PackageGUID & ")", 0 

		'****************** Lager først SOSIFelles.xsd og AbstraktNVDB.xsd *******************

		'Liste med GML-tagger til hovedpakke
		Set lstTags = CreateObject("System.Collections.SortedList")
		lstTags.Add "targetNamespace", strTargetNamespace
		lstTags.Add "version", FC_version
		lstTags.Add "xmlns", "nvdb"
		lstTags.Add "xsdDocument", "AbstraktNVDB.xsd"

		'Lager modell og hovedpakke, og importerer fellespakker
		createSCmodel("new")
		'Legger til arv fra SOSI Fellesegenskaper for abstrakte klasser og rydder i tagger
		Repository.WriteOutput "Script", Now & " Legger til arv fra SOSI Fellesegenskaper for abstrakte klasser og rydder i tagger", 0 

		dim ftSOSIfelles as EA.Element
		set ftSOSIfelles = pkSOSIfelles.Elements.GetByName("Fellesegenskaper")
		if not ftSOSIfelles is nothing then
			Repository.WriteOutput "Script", Now & " Elementet Fellesegenskaper funnet (" & ftSOSIfelles.ElementGUID & ")", 0 
			dim scEl as EA.Element
			for each scEl In absClasses.elements
				if UCase(scEl.Stereotype) ="FEATURETYPE" then
					Repository.WriteOutput "Script", Now & " FeatureType " & scEl.Name, 0 
					Repository.WriteOutput "Script", Now & " Sletter constraints ", 0 			
					'Sletter alle constraints
					for idxC = 0 to scEl.Constraints.Count - 1
						scEl.Constraints.DeleteAt idxC, false
					next
					scEl.Constraints.Refresh

					'rydder opp i role tags
					roleTags(scEl)	
					
					'Legger kun til arv fra Fellesegenskaper for de som skal ha det
					If scEl.Name = "AbstraktDokumentasjon" Or scEl.Name = "AbstraktKommentar" Or scEl.Name = "AbstraktSystemobjekt" Or Mid(scEl.Name, 1, 16) = "AbstraktTilstand" Then
						Repository.WriteOutput "Script", Now & " Legger ikke til arv fra SOSI Fellesegenskaper for objekttypen " & scEl.Name, 0
					Else
						Repository.WriteOutput "Script", Now & " Legger til arv fra SOSI Fellesegenskaper for objekttypen " & scEl.Name, 0
						set con = scEl.Connectors.AddNew("", "Generalization")
						con.ClientID = scEl.ElementID
						con.SupplierID = ftSOSIfelles.ElementID
						con.Update()
					End If
				end if
			next
		
			'Kjører ShapeChange, venter på fullføring
			runSC							
			'Flytter SOSIFelles.xsd og abstraktNVDB.xsd til riktig område
			moveFile "SOSIFelles.xsd", scPath & "\XSD\INPUT\",gmlPath & "\"
			moveFile "AbstraktNVDB.xsd", scPath & "\XSD\INPUT\",gmlPath & "\"	
		end if

		'Close SC
		scRep.CloseFile
		scRep.Exit
		set scRep = nothing	
		
		'Lag kopi av SC-prosjektet, for bruk som mal for prosessen med enkeltvise skjema.
		'Sletter eventuelt gammel fil
		If objFS.FileExists(scPath & "\" & scMal) then objFS.DeleteFile scPath & "\" & scMal, true
		objFS.CopyFile scPath & "\" & scProject, scPath & "\" & scTemplate
			
		'***************** Skjema pr vegobjekttype *****************************

		'Hardkoda liste over objekttyper som ikke skal være med i GML-eksporten
		dim lstOmit
		Set lstOmit = CreateObject("System.Collections.ArrayList")
		lstOmit.Add "532" 'Vegreferanse
		lstOmit.Add "618" 'Oppdrag_Fagdata 
		lstOmit.Add "619" 'Oppdrag_Vegnett
		lstOmit.Add "620" 'Oppgave_Fagdata 
		lstOmit.Add "621" 'Oppgave_Vegnett
		lstOmit.Add "622" 'SOSI-Bestilling
		lstOmit.Add "793" 'NVDBDokumentasjon
		'lstOmit.Add "871" 'Historisk Bruksklasse
		
		
		'Hardkoda liste over datatyper som skal fjernes fra den enkelte pakken, ettersom de finnes i SOSI Fellesegenskaper.
		dim lstDTOmit
		Set lstDTOmit = CreateObject("System.Collections.ArrayList")
		lstDTOmit.Add "Vegkategori" 
		lstDTOmit.Add "Vegfase" 
		lstDTOmit.Add "AdskilteLøp" 

		'Løkke for kjøring pr vegobjekttype
		for each pck in thePackage.Packages
			if not lstOmit.Contains(pck.Alias) and pck.PackageGUID <> guidAbstrakteKlasser then 'Vegreferanse m.fl. skal ikke være med
				Repository.WriteOutput "Script", Now & " ", 0 
				Repository.WriteOutput "Script", Now & " Lager applikasjonsskjemamodell for delpakken " & pck.Name & " (" & pck.PackageGUID & ")", 0 

				'Liste med GML-tagger til hovedpakke
				Set lstTags = CreateObject("System.Collections.SortedList")
				lstTags.Add "targetNamespace", strTargetNamespace
				lstTags.Add "version", FC_version
				lstTags.Add "xmlns", "nvdb"
				lstTags.Add "xsdDocument", pck.Alias & ".xsd"

				'Kobler til modell og hovedpakker
				createSCmodel("copy")
				'Importerer SOSI Fellesegenskaper-pakken til modellen ShapeChange
				'importSOSIFelles

				'Importerer aktuell objekttype sin pakke til modellen ShapeChange
				Repository.WriteOutput "Script", Now & " Importerer pakke for hovedobjekttypen " & pck.Name & " (fil: " & sosiPath & "\" & pck.Alias & ".xml)", 0 
				set pI = scRep.GetProjectInterface()
				pI.ImportPackageXMI scPck.PackageGUID, sosiPath & "\" & pck.Alias & ".xml", 1,0
				scPck.Packages.Refresh			

				'Importerer Abstrakte klasser-pakken til modellen ShapeChange
				'importAbstrakteKlasser
				set tagVal = absClasses.Element.TaggedValues.AddNew("xsdDocument", "AbstraktNVDB.xsd")
				tagVal.Update				

				'Fjerner eventuelle targetNamespace-tagger på delpakker
				dim scSubPck as EA.Package
				for each scSubPck in scPck.Packages
					for idxT = 0 to scSubPck.Element.TaggedValues.Count -1
						set tagVal = scSubPck.Element.TaggedValues.GetAt(idxT)
						if tagVal.Name = "targetNamespace" or tagVal.Value = "" then 
							Repository.WriteOutput "Script", Now & " Sletter tagged value " & scSubPck.Name & "." & tagVal.Name & " = " & tagVal.Value, 0 
							scSubPck.Element.TaggedValues.DeleteAt idxT,false
						end if
						if scSubPck.Alias = pck.Alias then
							'Fjerner alle tagged values på objekttypen sin pakke, den skal inngå i hovedpakken direkte.
							Repository.WriteOutput "Script", Now & " Sletter tagged value " & scSubPck.Name & "." & tagVal.Name & " = " & tagVal.Value, 0 
							scSubPck.Element.TaggedValues.DeleteAt idxT,false	
							for idxE = 0 to scSubPck.Elements.Count - 1 
								set element = scSubPck.Elements.GetAt(idxE)
								'Sletter alle constraints
								for idxC = 0 to element.Constraints.Count - 1
									element.Constraints.DeleteAt idxC, false
								next
								element.Constraints.Refresh	
								'Fjerner datatyper som finnes i SOSI Fellesegenskaper
								if UCase(element.Stereotype) <> "FEATURETYPE" and lstDTOmit.Contains(element.Name) then
									Repository.WriteOutput "Script", Now & " Sletter datatype " & scSubPck.Name & "." & element.Name, 0 
									scSubPck.Elements.DeleteAt idxE, false
								end if
							next
							scSubPck.Elements.Refresh
						end if
					next
					scSubPck.Element.TaggedValues.Refresh
				next	 
				
				'Close SC
				scRep.CloseFile
				scRep.Exit
				set scRep = nothing	
				'Kjører ShapeChange, venter på fullføring
				runSC							

				'Flytter pakken sin skjemafil til riktig område
				moveFile pck.Alias & ".xsd", scPath & "\XSD\INPUT\",gmlPath & "\"

				'Mulighet for å hoppe ut av løkka - fjernes når scriptet er ferdig.
				'msgAnsw = MsgBox("Sjekk SC-modellen nå", vbOkCancel, "GML-applikasjonsskjema")
				'if msgAnsw = 2 then
				'	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
				'	exit sub
				'end if	

			end if
		next

	end if
	
	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
	Repository.EnsureOutputVisible "Script"

end sub

Fellesskjema