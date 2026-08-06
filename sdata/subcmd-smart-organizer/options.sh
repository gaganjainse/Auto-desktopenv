showhelp(){
  printf "Syntax: $0 smart-organizer [OPTIONS]...
  
  Install or run the smart-organizer tool.
  
  Options:
    -h, --help                Print this help message and exit
    --dry-run                 Run in dry-run mode (no changes)
    --once                    Run once and exit
    --watch                   Watch mode (continuous)
    --clean                   Run cleanup only
    --organize                Run organization only
    --folders                 Run folder operations only
    --skip-smart-organizer    Skip smart-organizer setup during install
"
}
