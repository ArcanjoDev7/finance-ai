param(
  [Parameter(Mandatory = $true)]
  [string] $ProjectRef,
  [switch] $Local
)

$output = Join-Path $PSScriptRoot 'database.types.ts'
if ($Local) {
  supabase gen types typescript --local --schema public | Set-Content -Encoding utf8 $output
} else {
  supabase gen types typescript --project-id $ProjectRef --schema public | Set-Content -Encoding utf8 $output
}
