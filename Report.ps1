function GenerateCommitReport {
    param (
        [string]$folderPath,
        [array]$usersToFilter,
        [string]$csvPath
    )

    $currentDate = Get-Date
    $firstDayOfCurrentMonth = Get-Date -Day 1 -Month $currentDate.Month -Year $currentDate.Year
    $firstDayOfPreviousMonth = $firstDayOfCurrentMonth.AddMonths(-1)

    # Function to get all commits from a Git repository
    function Get-Commits {
        param (
            [string]$repoPath
        )

        $repoName = (Get-Item $repoPath).Name
        Set-Location $repoPath
        if (!(Test-Path .git)) {
            Write-Host "Skipping $repoName as it is not a Git repository"
            return @()
        }
        Write-Host "Processing $repoName"
        git pull | Out-Null #TODO: Check if access to remote repository is available
        $commits = git log --pretty=format:"$repoName,%ai,%an,%s" --date=iso --since='2 month ago'

        return $commits
    }

    # Iterate through each directory in the specified folder
    $repositories = Get-ChildItem -Path $folderPath -Recurse -Directory | Where-Object { (Get-ChildItem $_.FullName -Hidden -Directory -Filter ".git").Count -gt 0 }

    # Initialize an empty array to store all commits
    $allCommits = @()

    foreach ($repo in $repositories) {
        $repoCommits = Get-Commits -repoPath $repo.FullName
        $allCommits += $repoCommits
    }

    # Filter commits by specified users and date range
    $filteredCommits = $allCommits | Where-Object {
        $commitData = $_.Split(",")
        $commitDate = Get-Date $commitData[1]
        $userName = $commitData[2].Trim()
        ($usersToFilter -contains $userName) -and (
            (($commitDate.Month -eq $firstDayOfCurrentMonth.Month) -and ($commitDate.Year -eq $firstDayOfCurrentMonth.Year)) -or
            (($commitDate.Month -eq $firstDayOfPreviousMonth.Month) -and ($commitDate.Year -eq $firstDayOfPreviousMonth.Year))
        )
    }

    # Sort commits by commit date in descending order
    $sortedCommits = $filteredCommits | Sort-Object { [datetime]($_.Split(",")[1]) } -Descending

    # Convert to CSV format
    $csvData = $sortedCommits | ForEach-Object {
        $commitData = $_.Split(",")
        [PSCustomObject]@{
            Repository = $commitData[0]
            Date       = $commitData[1]
            Author     = $commitData[2]
            Message    = $commitData[3..($commitData.Length - 1)] -join ","
        }
    }

    # Output the commits to a CSV file
    $csvData | Export-Csv -Path $csvPath -NoTypeInformation

    Write-Host "CSV file has been generated: $csvPath"
}
