option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre

sub removeSpecificAttribute()
	'Setter opp kobling til modeller og databasetabell
	dim connect 
	connect = connect2UMLmodels()
	If not connect then exit sub

	'Spoler gjennom alle NVDB Datakatalog-delpakker i SOSI-modellregister
	Set lstSOSIpck = CreateObject("System.Collections.SortedList")
	Repository.WriteOutput "Script", Now & " Spoler gjennom alle NVDB Datakatalog-delpakker i SOSI-modellregister", 0 
	For each pkOT in pkSOSINVDB.Packages
		Repository.WriteOutput "Script", Now & " Pakke: " & pkOT.Name &  " (" & pkOT.Alias & ")", 0 
	Next
	
	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"
end sub

removeSpecificAttribute()