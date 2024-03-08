option explicit

!INC Local Scripts.EAConstants-VBScript
!INC MasterScript.NVDB til UML
!INC MasterScript.NVDB til SOSI
!INC MasterScript.Objektlister
!INC NVDB._felles
!INC NVDB._parametre

' Script Name: master
' Author: Aslak Wold
' Purpose: Master-script to be ran when there's a new version of NVDB-datakatalogen
' Date: 20221219

'Make sure to set the correct filepath for the new version of the 
'NVDB datakatlog in the const FC_DB 
'and version number in the const FC_versjon in the
'_parametre script in the NVDB folder.

dim nvdbPackage, abstrakteKlasser, sosiNVDBDatakatalogPackage, nvdbSosiProdSpec, newVersionPackage

set nvdbPackage = Repository.GetPackageByGuid(nvdbPackageGuid) 'NVDB package under SOSI Modell Andre viktige komponenter
set abstrakteKlasser = Repository.GetPackageByGuid(guidAbstrakteKlasser) '_AbstrakteKlasser
set sosiNVDBDatakatalogPackage = Repository.GetPackageByGuid(guidSOSIDatakatalog) '"ApplicationSchema" NVDB Datakatalogen
set nvdbSosiProdSpec = Repository.GetPackageByGuid(nvdbSosiProduktspesifikasjoner) 'NVDB Datakatalogen SOSI Produktspesifikasjoner package

'Trinn 1 og 2
NVDBTilUML

'Trinn 3 - 8 
NVDBTilSOSI


'Moving _AbstrakteKlasser to NVDB package if it's not there already
if abstrakteKlasser.ParentID <> nvdbPackage.PackageID then
	Repository.WriteOutput "Script", "_AbstrakteKlasser not in correct folder, moving to: NVDB...", 0
	abstrakteKlasser.ParentID = nvdbPackage.PackageID
	abstrakteKlasser.Update
end if

'Create a package in SOSI Produktspesifikasjoner under NVDB Datakatalogen
set newVersionPackage = nvdbSosiProdSpec.Packages.AddNew("NVDB Datakatalogen versjon " & FC_Version, "Package")
newVersionPackage.Update

'trinn 10 - 12
Objektlister


'Moving _AbstrakteKlasser to NVDB Datakatlogen
Repository.WriteOutput "Script", "Moving _AbstrakteKlasser package to: ApplicationSchema NVDB Datakatalogen...", 0
abstrakteKlasser.ParentID = sosiNVDBDatakatalogPackage.PackageID 
abstrakteKlasser.Update

Repository.WriteOutput "Script", "Finished running the scripts!", 0
msgbox "Finished running the scripts!", vbokonly, "Update finished"
