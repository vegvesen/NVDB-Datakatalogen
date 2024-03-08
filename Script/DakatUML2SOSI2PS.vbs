'option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre

' Script Name: DakatUML2SOSI2PS
' Author: Knut Jetlund
' Purpose: Generer produktspesifikasjon ut i fra koblingstabeller mot vegobjekttypekategori
' Date: 20210212
'

const votkatId = "302,303"

sub main

	'Vise og tøm scriptvinduer
	outputTabs
	'Kobler til modell og database
	connect2models
	'Henter tabell for vegobjekttypekategorier
	set rsVOTKategorier = CreateObject("ADODB.Recordset")
	rsVOTKategorier.Open "SELECT * FROM VEGOB_TYPE_KAT", dbDakat, 3, 1
	'Lager koblingstabell for vegobjekttyper og vegobjekttypekategorier	
	set rsVTKat = CreateObject("ADODB.Recordset")
	rsVTKat.Open "SELECT * FROM KOPL_VOT_KAT", dbDakat, 3, 1
	'Lager koblingstabell for egenskapstyper og vegobjekttypekategorier	
	set rsETKat = CreateObject("ADODB.Recordset")
	rsETKat.Open "SELECT * FROM KOPL_ET_KAT", dbDakat, 3, 1
	'Lager koblingstabell for kodelisteverdier og vegobjekttypekategorier	
	set rsTVKat = CreateObject("ADODB.Recordset")
	rsTVKat.Open "SELECT * FROM KOPL_TV_KAT", dbDakat, 3, 1
	
	'Hent valgt hovedpakke
	dim thePackage as EA.Package
	set thePackage = Repository.GetTreeSelectedPackage()
	dim pI as EA.Project					
	set pI = Repository.GetProjectInterface()
	Set objFS = CreateObject("Scripting.FileSystemObject")

	'Filtrerer kategori-koblingstabeller 
	dim lstVOTK
	lstVOTK = Split(votkatId,",")
	dim vk
	for each vk in lstVOTK
		rsVOTKategorier.Filter = "ID_VOBJ_TYP_KAT = " & VK
		
		'Lag ny PS-pakke for kategorien. Navn = Kategorinavn + Datakat-versjon
		dim katPackage as EA.Package
		Do Until rsVOTKategorier.EOF
			Repository.WriteOutput "Script", Now & " Vegobjekttypekategori: " & rsVOTKategorier.Fields("NAVN_VOBJ_TYP_KAT").Value & " (" & rsVOTKategorier.Fields("ID_VOBJ_TYP_KAT").Value & ")",0
			set katPackage = thePackage.Packages.AddNew(rsVOTKategorier.Fields("NAVN_VOBJ_TYP_KAT").Value,"Package")
			katPackage.Update
			set element = katPackage.Element
			element.Alias = rsVOTKategorier.Fields("ID_VOBJ_TYP_KAT").Value
			If rsVOTKategorier.Fields("BSKR_VOBJ_TYP_KAT").Value <> "" then element.Notes = rsVOTKategorier.Fields("BSKR_VOBJ_TYP_KAT").Value
			element.Update
			
			'For hver VOT i kategorien:
			rsVTKat.Filter = "ID_VOBJ_TYP_KAT = " & votkatId
			Do Until rsVTKat.EOF
				'Importer VOT sin XMI, strip GUIDs
				dim strFileName
				strFileName = sosiPath & "\" & rsVTKat.Fields("ID_VOBJ_TYPE").Value & ".xml"
				if objFS.FileExists(strFileName) then

					Repository.WriteOutput "Script", Now & " Importerer Vegobjekttype-XMI: " & strFileName,0
					'pI.ImportPackageXMI katPackage.PackageGUID, strFileName, 1,1
					'katPackage.Packages.Refresh			

				end if
				rsVTKat.MoveNext()
			Loop	

					'For hver attributt i VOT
					'rsETKat.Filter = = "ID_VOBJ_TYP_KAT = " & votkatId
					'Sjekk om den inngår i koblingsliste
					'Ja--> Obligatorisk.
					'Nei-->Slett. Inkludert tilhørende kodeliste

					'For hver kodelisteverdi
					'rsTVKat.Filter = = "ID_VOBJ_TYP_KAT = " & votkatId
					'Sjekk om den inngår i koblingsliste
					'Nei-->Slett. 

			rsVOTKategorier.MoveNext()
		Loop
	next

	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 

end sub

main()