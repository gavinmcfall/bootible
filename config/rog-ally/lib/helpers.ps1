# Bootible Helper Functions
# ==========================
# Pure functions with no side effects, safe to import for testing.

function Merge-Configs {
    <#
    .SYNOPSIS
        Recursively merges two configuration hashtables.
    .DESCRIPTION
        Override values take precedence. Nested hashtables are merged recursively.
        Non-hashtable values (arrays, strings, etc.) are replaced entirely.
    #>
    param(
        [hashtable]$Base,
        [hashtable]$Override
    )

    $result = $Base.Clone()

    foreach ($key in $Override.Keys) {
        if ($result.ContainsKey($key) -and $result[$key] -is [hashtable] -and $Override[$key] -is [hashtable]) {
            $result[$key] = Merge-Configs $result[$key] $Override[$key]
        } else {
            $result[$key] = $Override[$key]
        }
    }

    return $result
}

function Get-ConfigValue {
    <#
    .SYNOPSIS
        Gets a value from a nested config using dot notation.
    .EXAMPLE
        Get-ConfigValue -Config $config -Key "nested.level1.value" -Default "fallback"
    #>
    param(
        [hashtable]$Config,
        [string]$Key,
        $Default = $null
    )

    $keys = $Key -split '\.'
    $value = $Config

    foreach ($k in $keys) {
        if ($value -is [hashtable] -and $value.ContainsKey($k)) {
            $value = $value[$k]
        } else {
            return $Default
        }
    }

    return $value
}

function Convert-OrderedDictToHashtable {
    <#
    .SYNOPSIS
        Converts OrderedDictionary (from ConvertFrom-Yaml) to regular hashtable.
    .DESCRIPTION
        Recursively converts nested OrderedDictionary objects and arrays.
    #>
    param($OrderedDict)

    $hashtable = @{}
    foreach ($key in $OrderedDict.Keys) {
        $value = $OrderedDict[$key]
        if ($value -is [System.Collections.Specialized.OrderedDictionary]) {
            $hashtable[$key] = Convert-OrderedDictToHashtable $value
        } elseif ($value -is [System.Collections.IList] -and $value -isnot [string]) {
            $hashtable[$key] = @($value | ForEach-Object {
                if ($_ -is [System.Collections.Specialized.OrderedDictionary]) {
                    Convert-OrderedDictToHashtable $_
                } else {
                    $_
                }
            })
        } else {
            $hashtable[$key] = $value
        }
    }
    return $hashtable
}
