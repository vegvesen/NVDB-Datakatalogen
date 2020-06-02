option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre

' Script Name: Generer applikasjonsskjema pr vegobjekttype
' Author: Knut Jetlund
' Purpose: Massiv generering av applikasjonsskjema pr vegobjekttype
' Date: 20160916
'
' NOTE: Requires a package to be selected in the Project Browser
' 

sub main()

	dim msgAnsw
	' Show and clear the script output window
	Repository.EnsureOutputVisible "Script"
	Repository.ClearOutput "Script"
	Repository.CreateOutputTab "Error"
	Repository.ClearOutput "Error"

	' Get the currently selected package in the tree to work on
	dim thePackage as EA.Package
	set thePackage = Repository.GetTreeSelectedPackage()
		
	if not thePackage is nothing and thePackage.ParentID <> 0 then	
		Repository.WriteOutput "Script", Now & " Hovedpakke: " & thePackage.Name & " (" & thePackage.PackageGUID & ")", 0 
		Repository.WriteOutput "Script", Now & " Kobler til ShapeChange-prosjektet " & scPath & "\" & scProject, 0 
		'Kobler til ShapeChange-prosjektet
		dim scRep as EA.Repository
		set scRep = CreateObject("EA.Repository")
		scRep.OpenFile(scPath & "\" & scProject)
		'Sletter alle eksisterende modeller i ShapeChange-prosjektet
		Repository.WriteOutput "Script", Now & " Sletter alle eksisterende modeller i ShapeChange-prosjektet", 0 
		dim scMod as EA.Package
		dim i
		for i = 0 to scRep.Models.Count -1
			set scMod = scRep.Models.GetAt(i)
			Repository.WriteOutput "Script", Now & " Sletter modellen " & scMod.Name, 0 
			scRep.Models.DeleteAt i,false
		next
		scRep.Models.Refresh		
		'Lager basismodell
		Repository.WriteOutput "Script", Now & " Lager modellen ShapeChange med applikasjonsskjema NVDB", 0 
		set scMod = scRep.Models.AddNew("ShapeChange","")
		scMod.Update	
		
		'Lager hovedpakke i modellen ShapeChange
		'Repository.WriteOutput "Script", Now & " Lager hovedpakke NVDB med pakketilpassede tagger", 0 
		dim scPck as EA.Package
		set scPck = scMod.Packages.AddNew("NVDB","")
		scPck.Update
		scMod.Packages.Refresh
		scPck.StereotypeEx="applicationSchema"
		scPck.Update
		'Legger på GML-tagger på hovedpakka. Litt komplekst pga tagger både i og utenfor profil
		dim lstTags
		Set lstTags = CreateObject("System.Collections.SortedList")
		lstTags.Add "targetNamespace", strTargetNamespace
		lstTags.Add "version", FC_version
		lstTags.Add "xmlns", "nvdb"
		lstTags.Add "xsdDocument", "nvdb.xsd"
		
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

		dim pI as EA.Project					
		set pI = scRep.GetProjectInterface()
						
		'Importerer SOSI Fellesegenskaper-pakken til modellen ShapeChange
		Repository.WriteOutput "Script", Now & " Importerer SOSI Fellesegenskaper-pakken", 0 
		pI.ImportPackageXMI scPck.PackageGUID, sosiPath & "\SOSI Fellesegenskaper.xml", 1,0
				
		'Finn SOSI Fellesegenskaper og sett GML-tagger
		dim pkSOSIfelles as EA.Package
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

		dim pck as EA.Package

		'Leser inn hver pakke fra den valgte hovedmodellen 
		for each pck in thePackage.Packages
			if pck.Alias <> 532 and (pck.Alias= 67 or pck.Alias=470 or pck.Alias=794 or pck.Alias=446) then 
				'Vegreferanse skal ikke være med
				'Kun for test: Begrenser til objekttypen Antenne og tre assosierte objekttyper
				set pI = Repository.GetProjectInterface()
				'Repository.WriteOutput "Script", Now & " Eksporter filen " & sosiPath & "\" & pck.Alias & ".xml", 0 
				'pI.ExportPackageXMI pck.PackageGUID, 12, 1, -1, 1, 0, sosiPath & "\" & pck.Alias & ".xml"				
				set pI = scRep.GetProjectInterface()
				'Importerer aktuell objekttype sin pakke til modellen ShapeChange
				Repository.WriteOutput "Script", Now & " Kopierer pakke for objekttypen " & pck.Name & " til ShapeChange-prosjekt (fil: " & sosiPath & "\" & pck.Alias & ".xml)", 0 
				pI.ImportPackageXMI scPck.PackageGUID, sosiPath & "\" & pck.Alias & ".xml", 1,0
			end if
		next

		scPck.Packages.Refresh

		'Kjører gjennom alle pakker i SC-prosjektet. Ordner arv, assosiasjoner og tagger. 
		dim ftSOSIfelles as EA.Element
		set ftSOSIfelles = pkSOSIfelles.Elements.GetByName("Fellesegenskaper")
		if not ftSOSIfelles is nothing then
			Repository.WriteOutput "Script", Now & " Elementet Fellesegenskaper funnet (" & ftSOSIfelles.ElementGUID & ")", 0 		
			dim scSubPck as EA.Package
			for each scSubPck in scPck.Packages
				if scSubPck.PackageGUID <> pkSOSIfelles.PackageGUID then
					Repository.WriteOutput "Script", Now & " Ordner arv, assosiasjoner og tagger for pakken " & scSubPck.Name , 0 		
					'Fjerner eventuelle targetNamespace-tagger på delpakker
					for idxT = 0 to scSubPck.Element.TaggedValues.Count -1
						set tagVal = scSubPck.Element.TaggedValues.GetAt(idxT)
						if tagVal.Name = "targetNamespace" or tagVal.Value = "" then 
							Repository.WriteOutput "Script", Now & " Sletter tagged value " & scSubPck.Name & "." & tagVal.Name & " = " & tagVal.Value, 0 
							scSubPck.Element.TaggedValues.DeleteAt idxT,false
						end if
					next
					 scSubPck.Element.TaggedValues.Refresh

					'Finner selve objekttypen i den enkelte pakken, og ordner arv, assosiasjoner og tagger
					dim scEl as EA.Element
					for each scEl In scSubPck.elements
						if scEl.Stereotype="featureType" then
							'Sletter alle constraints
							for idxC = 0 to scEl.Constraints.Count - 1
								scEl.Constraints.DeleteAt idxC, false
							next
							scEl.Constraints.Refresh
							'rydder opp i role tags
							Dim rTag As EA.RoleTag
							dim rTagFound
							for each con in scEl.Connectors
								rTagFound = false
								for idxT = 0 to con.ClientEnd.TaggedValues.Count - 1
									set rTag = con.ClientEnd.TaggedValues.GetAt(idxT)
									if rTag.Tag = "inlineOrByReference" and not rTagFound then
										rTag.Value = "ByReference"
										rTag.Update
										rTagFound = true
									elseif rTagFound then
										con.ClientEnd.TaggedValues.DeleteAt idxT, false
									end  if
								next
								con.ClientEnd.TaggedValues.Refresh()
								con.ClientEnd.Update()

								rTagFound = false
								for idxT = 0 to con.SupplierEnd.TaggedValues.Count - 1
									set rTag = con.SupplierEnd.TaggedValues.GetAt(idxT)
									if rTag.Tag = "inlineOrByReference" and not rTagFound then
										rTag.Value = "ByReference"
										rTag.Update
										rTagFound = true
									elseif rTagFound then
										con.SupplierEnd.TaggedValues.DeleteAt idxT, false
									end  if
								next
								con.SupplierEnd.TaggedValues.Refresh()
								con.SupplierEnd.Update()
							next
							
							If scEl.Name = "Dokumentasjon" Or scEl.Name = "Kommentar" Or scEl.Name = "Systemobjekt" Or Mid(scEl.Name, 1, 8) = "Tilstand" Then
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
				end if	
			next
		else
			Repository.WriteOutput "Script", Now & " Finner ikke elementet Fellesegenskaper", 0 
			scRep.Exit
			exit sub
		end if		

		
		'Kjører ShapeChange, venter på fullføring
		Repository.WriteOutput "Script", Now & " Kjører ShapeChange...", 0 
		dim strLine
		strLine = """C:\Program Files (x86)\AdoptOpenJDK\jre-14.0.1.7-hotspot\bin\java.exe"" -Xms256m -Xmx1024m -Dfile.encoding=UTF-8 -jar "
		strLine = strLine & """C:\DATA\Programvare\ShapeChange-2.9.1\ShapeChange-2.9.1.jar"" -c ""C:\DATA\GitHub\vegvesen\NVDB-Datakatalogen\SC\config\ShapeChangeConfiguration.xml"""
		dim shell
		set shell=createobject("wscript.shell") 
		shell.run strLine, 1, true
		set shell=nothing	
		
		'Flytter filer til riktig område
		dim objFS
		Set objFS = CreateObject("Scripting.FileSystemObject")
		Repository.WriteOutput "Script", Now & " Sletter gamle skjemafiler på området " & gmlPath, 0
		if objFS.FolderExists(gmlPath) then objFS.DeleteFolder gmlPath, true
		Repository.WriteOutput "Script", Now & " Flytter nye skjemafiler til området " & gmlPath, 0 
		objFS.MoveFolder scPath & "\XSD\INPUT", gmlPath ', true

		Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
		Repository.EnsureOutputVisible "Script"
		scRep.CloseFile
		scRep.Exit
		set scRep = nothing	
	else
		' No package selected in the tree
		MsgBox( "This script requires a package to be selected in the Project Browser." & vbCrLf & _
			"Please select a package in the Project Browser and try again." )
	end if
	

end sub

main
