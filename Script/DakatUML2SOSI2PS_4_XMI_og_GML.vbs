'option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre

' Script Name: DakatUML2SOSI2PS_4_XMI_og_GML
' Author: Knut Jetlund
' Purpose: Eksport av XMI-filer og generering av GML-applikasjonsskjema for produktspesifikasjoner basert på vegkategorier
' Date: 20210219
'

dim scRep as EA.Repository
dim scMod as EA.Package
dim scPck as EA.Package

sub main

	'Vise og tøm scriptvinduer
	outputTabs
	'Kobler til modell og database
	connect2models

	'Hent valgt hovedpakke
	dim thePackage as EA.Package
	set thePackage = Repository.GetTreeSelectedPackage()
	Repository.WriteOutput "Script", Now & " Hovedpakke: " & thePackage.Name & " (" & thePackage.PackageGUID & ")", 0 
	
	dim pI as EA.Project					
	Set objFS = CreateObject("Scripting.FileSystemObject")

	dim katPackage as EA.Package
	for each katPackage in thePackage.Packages
		Repository.WriteOutput "Script", Now & " Pakke for kategori: " & katPackage.Name & " (" & katPackage.Alias & ")", 0 

		dim strXMI
		strXMI = sosiPath & "\" & katPackage.Alias & ".xml"

		'Eksporter XMI-fil
		set pI = Repository.GetProjectInterface()
		Repository.WriteOutput "Script", Now & " Eksporter filen " & strXMI, 0 
		pI.ExportPackageXMI katPackage.PackageGUID, 12, 1, -1, 1, 0, strXMI		
		
		'Lager ShapeChange-prosjektet
		Repository.WriteOutput "Script", Now & " Lager ShapeChange-prosjektet " & scPath & "\" & scProject, 0 
		'Sletter eventuelt gammel fil
		If objFS.FileExists(scPath & "\" & scProject) then objFS.DeleteFile scPath & "\" & scProject, true
		set scRep = CreateObject("EA.Repository")
		scRep.CreateModel cmEAPFromBase, scPath & "\" & scProject,1
		scRep.OpenFile(scPath & "\" & scProject)
		Repository.WriteOutput "Script", Now & " Lager modellen ShapeChange", 0 
		set scMod = scRep.Models.AddNew("ShapeChange","")
		scMod.Update	
		scRep.Models.Refresh	
		'Importerer XMI-fil
		set pI = scRep.GetProjectInterface()
		Repository.WriteOutput "Script", Now & " Importerer pakken " & katPackage.Name & " (" & strXMI & ")", 0 
		pI.ImportPackageXMI scMod.PackageGUID, strXMI, 1,0

		'Fjern alle constraints, for penere logfil
		dim kPck as EA.Package
		dim vPck as EA.Package
		dim el as EA.Element
		for each kPck in scMod.Packages
			'Bytter navn til NVDB for hovedpakken (som definert i ShapeChangeConfiguration.xml)
			kPck.Name = "NVDB"
			kPck.Update
			for each vPck in kPck.Packages
				Repository.WriteOutput "Script", Now & " Sletter constraints i pakken " & vPck.Name, 0 			
				for each el in vPck.Elements
					'Sletter alle constraints
					for idxC = 0 to el.Constraints.Count - 1
						el.Constraints.DeleteAt idxC, false
					next
					el.Constraints.Refresh
				next
			next
		next

		scRep.CloseFile
		scRep.Exit
		set scRep = nothing	

		'Mulighet for å hoppe ut av løkka - fjernes når scriptet er ferdig.
		dim msgAnsw
		'msgAnsw = MsgBox("Sjekk status", vbOkCancel, "Script")
		'if msgAnsw = 2 then
		'	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
		'	exit sub
		'end if	


		'TODO: Kjør GML-generering vha ShapeChange
		Repository.WriteOutput "Script", Now & " Kjører ShapeChange...", 0 
		dim strLine
		strLine = """C:\Program Files (x86)\AdoptOpenJDK\jre-14.0.1.7-hotspot\bin\java.exe"" -Xms256m -Xmx1024m -Dfile.encoding=UTF-8 -jar "
		strLine = strLine & """C:\DATA\Programvare\ShapeChange-2.9.1\ShapeChange-2.9.1.jar"" -c ""C:\DATA\GitHub\vegvesen\NVDB-Datakatalogen\SC\config\ShapeChangeConfiguration.xml"""
		dim shell
		set shell=createobject("wscript.shell") 
		shell.run strLine, 1, true
		set shell=nothing	

		'TODO: Lag mappestruktur og flytt filer
		dim strFolder
		strFolder = gmlPath & "\PS" 
		if not objFS.FolderExists(strFolder) then objFS.CreateFolder strFolder
		strFolder = strFolder & "\" & katPackage.Alias
		if not objFS.FolderExists(strFolder) then objFS.CreateFolder strFolder
		strFolder = strFolder & "\" & FC_version
				
		if objFS.FolderExists(strFolder) then
			Repository.WriteOutput "Script", Now & " Mappen " & strFolder & " finnes fra før slettes", 0 
			objFS.DeleteFolder strFolder
		else
			Repository.WriteOutput "Script", Now & " Mappen finnes ikke fra før", 0 
		end if
		Repository.WriteOutput "Script", Now & " Oppretter mappen " & strFolder, 0 
		objFS.CreateFolder strFolder
		'Flytter filer
		Repository.WriteOutput "Script", Now & " Flytter filer fra " & scPath & "\XSD\INPUT\*.xsd" & " til " & strFolder, 0 
		objFS.MoveFile scPath & "\XSD\INPUT\*.xsd", strFolder & "\"

		'Mulighet for å hoppe ut av løkka - fjernes når scriptet er ferdig.
		'msgAnsw = MsgBox("Sjekk status", vbOkCancel, "Script")
		'if msgAnsw = 2 then
		'	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
		'	exit sub
		'end if	
	next

	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 

end sub

main()