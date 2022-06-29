class OceanStorWorkload {
    [string]${Workload Id}
    [string]${Workload Name}
    [string]${Workload Type}
    [string]${Block Size}
    [string]${Compression Enabled}
    [string]${Deduplication Enabled}
    [string]${Application Type}
    [string]${DataDistribution Alg.}

    OceanStorWorkload([array]$workloadReceived){

        $this.{Workload Id} = $workloadReceived.ID
        $this.{Workload Name} = $workloadReceived.NAME

        switch ($workloadReceived.CREATETYPE)
        {
            0 {$this.{Workload Type} = "preset"}
            1 {$this.{Workload Type} = "customized"}
        }

        switch ($workloadReceived.BLOCKSIZE)
        {
            0 {$this.{Block Size} = "4 KB"}
            1 {$this.{Block Size} = "8 KB"}
            2 {$this.{Block Size} = "16 KB"}
            3 {$this.{Block Size} = "32 KB"}
            4 {$this.{Block Size} = "64 KB"}
            5 {$this.{Block Size} = ">64 KB"}
        }

        switch ($workloadReceived.ENABLECOMPRESS)
        {
            false {$this.{Compression Enabled} = "disabled"}
            true {$this.{Compression Enabled} = "enabled"}
        }

        switch ($workloadReceived.ENABLEDEDUP)
        {
            false {$this.{Deduplication Enabled} = "disabled"}
            true {$this.{Deduplication Enabled} = "enabled"}
        }

        switch ($workloadReceived.templateType)
        {
            0 {$this.{Application Type} = "lun"}
            1 {$this.{Application Type} = "file system"}
        }

        switch ($workloadReceived.distAlg)
        {
            0 {$this.{DataDistribution Alg.} = "performance mode"}
            1 {$this.{DataDistribution Alg.} = "capacity balancing mode"}
            2 {$this.{DataDistribution Alg.} = "directory balance mode"}
            3 {$this.{DataDistribution Alg.} = "directory shuffle mode"}
        }
    }
}