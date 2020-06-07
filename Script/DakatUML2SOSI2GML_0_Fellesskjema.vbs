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

sub createSCmodel
'Lager ShapeChange-EA-prosjekt og modell
	Repository.WriteOutput "Script", Now & " Lager ShapeChange-prosjektet " & scPath & "\" & scProject, 0 
	'Sletter eventuelt gammel fil
	If objFS.FileExists(scPath & "\" & scProject) then objFS.DeleteFile scPath & "\" & scProject, true
	'msgAnsw = MsgBox("Sjekk SC-modellen n�", vbOkCancel, "GML-applikasjonsskjema")

	'Create and connect to model. 
	set scRep = CreateObject("EA.Repository")
	scRep.CreateModel cmEAPFromBase, scPath & "\" & scProject,1
	scRep.OpenFile(scPath & "\" & scProject)
	set pI = scRep.GetProjectInterface()
	
	'Lager basismodell ShapeChange
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
	
	'Legger p� GML-tagger p� hovedpakka. Litt komplekst pga tagger b�de i og utenfor profil
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
		'Setter GML-tagger p� SOSI Fellesegenskaper
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
		'Setter GML-tagger p� SOSI Fellesegenskaper
		set tagVal = absClasses.Element.TaggedValues.AddNew("version", FC_version)
		tagVal.Update
		set tagVal = absClasses.Element.TaggedValues.AddNew("xmlns", "nvdb")
		tagVal.Update
		'set tagVal = absClasses.Element.TaggedValues.AddNew("xsdDocument", "abstraktNVDB.xsd")
		'tagVal.Update				
		set tagVal = absClasses.Element.TaggedValues.AddNew("xsdEncodingRule", "sosi")
		tagVal.Update
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
	'Kj�rer ShapeChange, venter p� fullf�ring
	Repository.WriteOutput "Script", Now & " Kj�rer ShapeChange...", 0 
	dim strLine
	strLine = """C:\Program Files (x86)\AdoptOpenJDK\jre-14.0.1.7-hotspot\bin\java.exe"" -Xms256m -Xmx1024m -Dfile.encoding=UTF-8 -jar "
	strLine = strLine & """C:\DATA\Programvare\ShapeChange-2.9.1\ShapeChange-2.9.1.jar"" -c ""C:\DATA\GitHub\vegvesen\NVDB-Datakatalogen\SC\config\ShapeChangeConfiguration.xml"""
	dim shell
	set shell=createobject("wscript.shell") 
	shell.run strLine, 1, true
	set shell=nothing	
end sub

sub movefile(strFileName, strOldPath, strNewPath)
'Flytter angitt fil fra et omr�de til et annet
	if objFS.FileExists(strNewPath & strFileName) then
		Repository.WriteOutput "Script", Now & " Filen " & strNewPath & strFileName & " finnes fra f�r slettes", 0 
		objFS.DeleteFile strNewPath & strFileName
	else
		'Repository.WriteOutput "Script", Now & " Filen finnes ikke fra f�r", 0 
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

		'Liste med GML-tagger til hovedpakke
		Set lstTags = CreateObject("System.Collections.SortedList")
		lstTags.Add "targetNamespace", strTargetNamespace
		lstTags.Add "version", FC_version
		lstTags.Add "xmlns", "nvdb"
		lstTags.Add "xsdDocument", "AbstraktNVDB.xsd"

		'Lager modell og hovedpakke
		createSCmodel
		'Importerer SOSI Fellesegenskaper-pakken til modellen ShapeChange
		importSOSIFelles
		'Importerer Abstrakte klasser-pakken til modellen ShapeChange
		importAbstrakteKlasser
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
		
			'Kj�rer ShapeChange, venter p� fullf�ring
			runSC							
			'Flytter SOSIFelles.xsd og abstraktNVDB.xsd til riktig omr�de
			moveFile "SOSIFelles.xsd", scPath & "\XSD\INPUT\",gmlPath & "\"
			moveFile "abstraktNVDB.xsd", scPath & "\XSD\INPUT\",gmlPath & "\"	
		end if

		'Close SC
		scRep.CloseFile
		scRep.Exit
		set scRep = nothing	
		'Delete SC
		objFS.DeleteFile scPath & "\" & scProject, true


	end if
	
	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
	Repository.EnsureOutputVisible "Script"

end sub

Fellesskjema