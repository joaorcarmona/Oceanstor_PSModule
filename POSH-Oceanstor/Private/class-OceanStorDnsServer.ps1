class OceanStorDnsServer {
    [string]$Address
    [int]$Position

    OceanStorDnsServer([string]$Address, [int]$Position) {
        $this.Address = $Address
        $this.Position = $Position
    }
}
