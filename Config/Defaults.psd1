@{
    StateScores = @{
        Healthy  = 1.0
        Info     = 0.95
        Warning  = 0.7
        Critical = 0.0
        Unknown  = 0.5
        Ignored  = 0
    }

    DomainWeights = @{
        Instance    = 1.0
        Databases   = 1.3
        Backups     = 1.7
        Jobs        = 1.1
        Performance = 1.4
        ErrorLog    = 1.0
    }
}
