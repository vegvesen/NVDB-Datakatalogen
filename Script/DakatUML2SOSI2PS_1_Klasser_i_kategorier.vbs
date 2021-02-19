'option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre

' Script Name: DakatUML2SOSI2PS_1_Klasser_i_kategorier
' Author: Knut Jetlund
' Purpose: Lager hovedpakke for  produktspesifikasjon for valgte vegobjekttypekategorier, ut fra koblingstabeller
' Date: 20210216
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
	
	'Hent valgt hovedpakke
	dim thePackage as EA.Package
	set thePackage = Repository.GetTreeSelectedPackage()
	Repository.WriteOutput "Script", Now & " Hovedpakke: " & thePackage.Name & " (" & thePackage.PackageGUID & ")", 0 

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
			
			'TODO: Importer SOSIFelles og Abstrakte klasser
			'TODO: Legge til arv fra SOSIFelles til abstrakte klasser
			'TODO: Rydde i abstrakte klasser og assosiasjoner. Howto?
			
			
			'For hver VOT i kategorien:
			rsVTKat.Filter = "ID_VOBJ_TYP_KAT = " & votkatId
			Do Until rsVTKat.EOF
				'Importer VOT sin XMI, strip GUIDs
				dim strFileName
				strFileName = sosiPath & "\" & rsVTKat.Fields("ID_VOBJ_TYPE").Value & ".xml"
				if objFS.FileExists(strFileName) then

					Repository.WriteOutput "Script", Now & " Importerer Vegobjekttype-XMI: " & strFileName,0
					pI.ImportPackageXMI katPackage.PackageGUID, strFileName, 1,1
					katPackage.Packages.Refresh			

				end if
				rsVTKat.MoveNext()
			Loop	
			rsVOTKategorier.MoveNext()
		Loop
	next

	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 

end sub

main()