# Helper function to allow like comparison for each item in an array, against a property (or nested property) in a collection
function Invoke-LikeFilter {
    [cmdletbinding()]
    param(
        $Collection, # Collection to filter
        $PropertyName, # Filter on this property in the Collection.  If not specified, use each item in collection
        [object[]]$NestedPropertyName, # Filter on this array of nested properties in the Collection.  e.g. department, name = $Collection.Department.Name
        [string[]]$FilterArray, # Array of strings to filter on with a -like operator
        [ValidateCount(2,2)][string[]]$FilterReplace, # using array to get the parameters for the .replace() method to run on every object in the FilterArray
        #Added to be able to replace Windows back slashes with the forward slashes used in the Git paths but could be used for other things
        [switch]$Not # return items that are not -like...
    )
    if($FilterArray)
    {
        Write-Verbose "Running FilterArray [$FilterArray] against [$($Collection.count)] items"
        if ($PSBoundParameters.ContainsKey('FilterReplace'))
        {
            [string[]]$NormalizedFilterArray = @()
            foreach ($filter in $FilterArray) {
                $NormalizedFilterArray += $filter.replace($FilterReplace[0],$FilterReplace[1])
            }
            $FilterArray = $NormalizedFilterArray
            Write-Verbose "Strings have been normalized to [$FilterArray]"
        }
        $Collection | Where-Object {
            $Status = $False
            foreach($item in $FilterArray)
            {
                if($PropertyName)
                {
                    if($_.$PropertyName -like $item)
                    {
                        $Status = $True
                    }
                }
                elseif($NestedPropertyName)
                {
                    $dump = $_
                    $Value = $NestedPropertyName | Foreach-Object -process {$dump = $dump.$_} -end {$dump}
                    if($Value -like $item)
                    {
                        $Status = $True
                    }
                }
                else
                {
                    if($_ -like $item)
                    {
                        $Status = $True
                    }
                }
            }
            if($Not)
            {
                -not $Status
            }
            else
            {
                $Status
            }
        }
    }
    else
    {
        $Collection
    }
}
