option explicit

!INC Local Scripts.EAConstants-VBScript
!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre
'!INC NVDB.DakatUML2SOSI_0_Felles

' Script Name: 
' Author: Knut Jetlund
' Purpose: 
' Date: 


sub updateOnePackage
	
	' Get the currently selected package in the tree to work on
	dim thePackage as EA.Package
	set thePackage = Repository.GetTreeSelectedPackage()
		
	if not thePackage is nothing then
		dim connect 
		connect = connect2UMLmodels()
		If not connect then exit sub
		
		Repository.WriteOutput "Script", Now & " Oppdatering av vegobjekttyper i SOSI-modellregister", 0 
		Repository.WriteOutput "Script", Now & " ", 0 
		
		'Lag liste med Datakatalogpakker med NVDB-ID og GUID
		Set lstNVDBpck = CreateObject("System.Collections.SortedList")
		Repository.WriteOutput "Script", Now & " Lager liste over alle vegobjekttyper i NVDB Datakatalogen", 0 
		For each pkOT in pkObjekttyper.Packages
			Repository.WriteOutput "Script", Now & " NVDB-pakke: " & pkOT.Name &  " (" & pkOT.Alias & ")", 0 
			lstNVDBpck.Add pkOT.Alias,pkOT.packageGUID
		Next
		
		set pkOT = thePackage
		if lstNVDBpck.Contains(pkOT.Alias) then 
			'Eksisterer i NVDB, oppdateres
			Repository.WriteOutput "Script", Now & " SOSI-Pakke funnet i NVDB, oppdateres: " & pkOT.Name &  " (" & pkOT.Alias & ")", 0 
			'Henter NVDB-pakke vha listeinformasjon
			dim keyIndex
			keyIndex = lstNVDBpck.IndexofKey(pkOT.Alias)
			dim guid
			guid = lstNVDBpck.GetByIndex(keyIndex)
			set pkOT_NVDB = Repository.GetPackageByGuid(guid)
			updatePackage
		else
			'Eksisterer ikke i NVDB, slettes
			Repository.WriteOutput "Endringer", Now & " SOSI-Pakken finnes ikke i NVDB, fjernes: " & pkOT.Name &  " (" & pkOT.Alias & ")", 0 
			'pkSOSINVDB.Packages.DeleteAt idxP, False
		end if 
			
		Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
		Repository.EnsureOutputVisible "Script"
	else
		' No package selected in the tree
		MsgBox( "This script requires a package to be selected in the Project Browser." & vbCrLf & _
			"Please select a package in the Project Browser and try again." )
	end if
end sub

updateOnePackage