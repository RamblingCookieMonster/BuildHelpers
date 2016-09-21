# Helper function to allow like comparison for each item in an array, against a property (or nested property) in a collection
function Invoke-LikeFilter {
    [cmdletbinding()]
    param(
        $Collection, # Collection to filter
        $PropertyName, # Filter on this property in the Collection.  If not specified, use each item in collection
        [object[]]$NestedPropertyName, # Filter on this array of nested properties in the Collection.  e.g. department, name = $Collection.Department.Name
        [string[]]$FilterArray, # Array of strings to filter on with a -like operator
        [switch]$Not # return items that are not -like...
    )
    
    if($FilterArray.count -gt 0)
    {
        Write-Verbose "Running FilterArray [$FilterArray] against [$($Collection.count)] items"
        $Collection | Where {
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
                    # Code injection, beware...
                    $Value = Invoke-Expression "`$_.$($NestedPropertyName -join '.')"
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