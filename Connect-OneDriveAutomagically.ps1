[CmdletBinding()]
param (
	# Forcer l'installation
	[switch] $ForceInstall,
	# Forcer la synchronisation
	[switch] $ForceSync,
	# Adresse courriel de l'utilisateur
	[Parameter(Mandatory = $false, ValueFromPipeline = $true)]
	[ValidateScript(
		{
			if ($_.Split('@').Count -eq 2 -and $_.Split('@')[1].Split('.').Count -ge 2)
			{
				return $true
			}
			throw "Adresse courriel non valide."
			return $false
		})]
	[string] $UserEmail,
	[Parameter(Mandatory = $false, ValueFromPipeline = $true)]
	[string] $TenantEmailDomain = "contoso.com",
	# Nom du paquet logiciel de OneDrive
	[Parameter(Mandatory = $false, ValueFromPipeline = $true)]
	[string] $OneDrivePackageName = "Microsoft.OneDrive",
	# Répertoire de CSVs à synchroniser
	[Parameter(Mandatory = $false)]
	[ValidateScript({
			return Test-Path $_
		})]
	[System.IO.FileInfo] $LibrariesListPath = [System.IO.FileInfo] ".\SharePoint"
)

function Get-UserEmailAddress
{
	[OutputType([string])]
	[string] $email
	Write-Debug "Vérification que au cas où un adresse courriel a déjà été fournie en paramètre..."
	if ([string]::IsNullOrEmpty($UserEmail))
	{
		Write-Debug "Récupération de l'adresse courriel..."
		try
		{
			Import-Module ActiveDirectory
			$ADUser = Get-ADUser $env:USERNAME -Properties EmailAddress
			Write-Debug $local:ADUser.EmailAddress
			$local:email = $local:ADUser.EmailAddress
		}
		catch
		{
			Write-Host "Impossible de consulter ActiveDirectory pour obtenir l'adresse courriel.`nConstruction de l'adresse à partir du nom d'utilisateur..."
			$email = "$env:USERNAME@$script:TenantEmailDomain"
		}
	}
	else
	{
		Write-Debug "Adresse courriel déjà fournie."
		$local:email = $UserEmail
	}
	Write-Host "Utilisation de « $local:email »."
	return [string] $local:email.Trim()
}

function Install-OneDrive
{
	Write-Debug "Vérification de la présence de OneDrive..."
	# Inspiré par https://chrislayers.com/2021/08/01/scripting-winget/
	$installedAppsList = winget list --exact -q $script:OneDrivePackageName --accept-source-agreements
	if ((![string]::Join("", $local:installedAppsList).Contains($script:OneDrivePackageName)) -or $script:ForceInstall)
	{
		Write-Debug "OneDrive n'est pas installé."
		Write-Host "Installation de OneDrive..."
		if ($script:ForceInstall)
		{
			winget install --exact --silent $script:OneDrivePackageName --force --accept-source-agreements
		}
		else
		{
			winget install --exact --silent $script:OneDrivePackageName --accept-source-agreements
		}
	}
	Write-Debug "Fin de l'installation de OneDrive."
}

function Connect-OneDrive ([string] $EmailAddress)
{
	Write-Debug "Vérification que OneDrive est configuré pour le compte professionnel..."
	# if (([string]::IsNullOrEmpty($env:OneDriveCommercial) -and ((Get-ChildItem -Directory | Where-Object { $_.PSIsContainer -and $_.Name.StartsWith("OneDrive - ") }).Count -le 0)) -or $script:ForceSync)
	if ([string]::IsNullOrEmpty($env:OneDriveCommercial) -or $script:ForceSync)
	{
		Write-Host "Configuration de OneDrive en cours avec l'adresse « $local:EmailAddress »..."
		Start-Process "odopen://sync?userEmail=$local:EmailAddress" # Lancement demandant le démarrage de la synchronisation avec une adresse courriel spécifique
		Write-Host "Attente de la fin de la configuration..."
		while ((Get-ChildItem -Path $env:USERPROFILE -Directory | Where-Object { $_.PSIsContainer -and $_.Name.StartsWith("OneDrive - ") }).Count -le 0)
		{
			Start-Sleep -Seconds 5
			Write-Host -NoNewline "."
		}
		Write-Host
		Write-Host "OneDrive a commencé à synchroniser.`nAttente de 30 secondes pour laisser le temps de finir la configuration avant de continuer."
		Start-Sleep 30
		Write-Debug "Fin de la configuration de OneDrive."
	}
}

function Sync-Libraries ([string] $Email, [System.IO.FileInfo] $Path, [switch] $Force)
{
	[string] $librariesListFile
	if (Test-Path $local:Path -PathType Leaf)
	{
		$local:librariesListFile = $local:Path
	}
	else
	{
		[string] $librariesListFile = "$local:Path\$($script:email.Split('@')[0].Trim()).csv"
	}

	Write-Debug "Lancement de la procédure de synchronisation des bibliothèques selon le fichier « $local:Path »..."
	.\Sync-SharePointLibraries.ps1 -UserEmail $local:Email.Trim() -LibrariesListPath $local:librariesListFile -Force:$local:Force
}



[string] $email = Get-UserEmailAddress
if ([string]::IsNullOrEmpty($email))
{
	throw "Aucune adresse courriel fournie. Le script ne poursuivra pas son exécution.`nVérifiez que l'adresse courriel est présente dans l'objet Utilisateur ActiveDirectory ou qu'elle est fournie en paramètre d'exécution de ce script."
}

Install-OneDrive
Connect-OneDrive -EmailAddress $script:email
Sync-Libraries -Email $script:email -Path $script:LibrariesListPath -Force:$script:ForceSync

exit
