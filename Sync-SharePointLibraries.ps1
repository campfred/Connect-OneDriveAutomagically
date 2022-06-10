[CmdletBinding()]
param (
	# Forcer la synchronisation
	[Parameter(Mandatory = $false, ValueFromPipeline = $true)]
	[switch] $Force,
	[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $UserEmail,
	# Chemin de la liste à synchroniser
	[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
	[ValidateScript({
			Write-Host $_
			if (-Not ($_ | Test-Path) ) { throw "Le fichier n'existe pas." }
			if (-Not ($_ | Test-Path -PathType Leaf) ) { throw "Le chemin doit être un fichier. Les chemins de répertoires ne sont pas valides." }
			if ($_ -notmatch "(\.csv)") { throw "Le fichier spécifié dans le chemin doit être une liste CSV." }
			return $true
		})]
	[System.IO.FileInfo] $LibrariesListPath,
	[Parameter(Mandatory = $false)]
	[int] $DelayBetweenSyncs = 5
)

function Test-FolderSync ([System.IO.FileInfo] $Path)
{
	# File attribute fields : https://docs.microsoft.com/en-us/dotnet/api/system.io.fileattributes?view=net-6.0#fields
	# Bitwise operators : https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_arithmetic_operators?view=powershell-7.2#bitwise-operators
	return ((Get-ItemProperty $Path).Attributes.value__ -band [System.IO.FileAttributes]::ReparsePoint.value__) -eq 1024
}


[string] $tenantName
if (-Not [string]::IsNullOrEmpty($env:OneDriveCommercial))
{
	$script:tenantName = ([System.IO.FileInfo] $env:OneDriveCommercial).Name.Split('-')[1].Trim()
}
else
{
	$script:tenantName = (Get-ChildItem -Path $env:USERPROFILE -Directory | Where-Object { $_.PSIsContainer -and $_.Name.StartsWith("OneDrive - ") })[0].Name.Split('-')[1].Trim()
}
Write-Debug "Nom de l'organisation à regarder : $script:tenantName"
[System.IO.FileInfo] $tenantDirectory = "$env:USERPROFILE\$script:tenantName"
$sharePointLibraries = Get-Content $script:LibrariesListPath | ConvertFrom-Csv
Write-Debug "$($script:sharePointLibraries.Count) bibliothèques à synchroniser."

for ($indexLibrary = 0; $indexLibrary -lt $script:sharePointLibraries.Count; $indexLibrary++)
{
	$sharePointLibrary = $sharePointLibraries[$indexLibrary]
	Write-Debug "Vérification que « $($local:sharePointLibrary.SiteName) - $($local:sharePointLibrary.LibraryName) » est configuré..."
	Write-Progress -Id 1 -Activity "Synchronisation des bibliothèques SharePoint pour $script:UserEmail" -Status "Vérification de la présence de « $($local:sharePointLibrary.SiteName) - $($local:sharePointLibrary.LibraryName) »" -PercentComplete (($indexLibrary + 1) / $script:sharePointLibraries.Count * 100)
	$Exists = Test-Path -Path "$script:tenantDirectory\$($local:sharePointLibrary.SiteName) - $($local:sharePointLibrary.LibraryName)"
	Write-Debug "Existe : $Exists / Est inexistant : $(!$Exists)"
	$HasSyncAttribute = Test-FolderSync -Path "$script:tenantDirectory\$($local:sharePointLibrary.SiteName) - $($local:sharePointLibrary.LibraryName)"
	Write-Debug "A l'attribut de synchronisation : $HasSyncAttribute / N'a pas l'attribut de synchronisation : $(!$HasSyncAttribute)"
	Write-Debug "Synchronisation forcée : $script:Force"

	if (!($Exists) -or (!$HasSyncAttribute) -or $script:Force)
	{
		Write-Debug "Bibliothèque absente. Synchronisation de la bibliothèque..."
		Write-Progress -Id 1 -Activity "Synchronisation des bibliothèques SharePoint pour $script:UserEmail" -Status "Démarrage de la synchronisation « $($local:sharePointLibrary.SiteName) - $($local:sharePointLibrary.LibraryName) »" -PercentComplete (($indexLibrary + 1) / $script:sharePointLibraries.Count * 100)
		Write-Host "Synchronisation de « $($local:sharePointLibrary.SiteName) - $($local:sharePointLibrary.LibraryName) »..."

		$synchronizationURI = "odopen://sync/?userEmail=$script:UserEmail&webTitle=$($local:sharePointLibrary.SiteName)&listTitle=$($local:sharePointLibrary.LibraryName)&$($local:sharePointLibrary.SynchronizationString)"
		Write-Debug "URI de synchronisation forgée : $local:synchronizationURI"
		Start-Process "odopen://sync/?userEmail=$script:UserEmail&webTitle=$($local:sharePointLibrary.SiteName)&listTitle=$($local:sharePointLibrary.LibraryName)&$($local:sharePointLibrary.SynchronizationString)"
			
		# Attente pour laisser OneDrive digérer ça avant d'y pitcher le prochain.
		do
		{
			Start-Sleep -Seconds $script:DelayBetweenSyncs
			Write-Host -NoNewline "."
		} while (-not (Test-FolderSync -Path "$script:tenantDirectory\$($local:sharePointLibrary.SiteName) - $($local:sharePointLibrary.LibraryName)"))
	}
	else
	{
		Write-Debug "Bibliothèque existante. On passe..."
	}
}
Write-Progress -Id 1 -Activity "Synchronisation des bibliothèques SharePoint pour $script:UserEmail" -PercentComplete (100)

exit
