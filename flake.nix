{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }: 
    flake-utils.lib.eachDefaultSystem
      (system: 
        let 
          name = "my-app";
          src = ./.;
          pkgs = nixpkgs.legacyPackages.${system};

          # postgres options
          dbName = "test";
          pgOptions = "-l logfile -o \"--unix_socket_directories=\"$PWD\"\"";

          nativeBuildInputs = [];
          buildInputs = builtins.attrValues {
            inherit (pkgs)
            nodejs_24
            postgresql;
          };

          # postgres helper scripts
          startdb = pkgs.writeScriptBin "startdb" ''
            ${pkgs.postgresql}/bin/pg_ctl ${pgOptions} start;
          '';
          stopdb = pkgs.writeScriptBin "stopdb" ''
            ${pkgs.postgresql}/bin/pg_ctl stop;
          '';
        in
        {
          devShells.default = pkgs.mkShell {
            inherit buildInputs dbName;
            
            packages = [ startdb stopdb ];
            
            shellHook = ''
            # npm init on first run
            [ ! -e "./package.json" ] && npm init -y

            export PGDATA=./.tmp/${dbName};

            # Create a database with the data stored in the current directory if it doesnt exist
            if [ ! -d "./.tmp/${dbName}" ]; then
                initdb 
                # Start PostgreSQL running as the current user
                # and with the Unix socket in the current directory
                startdb

                # Create a database
                # need pwd to pass in custom socket
                createdb ${dbName} -h "$PWD"
                
                # stop db for manual control
                stopdb
            else
              true;
            fi;
            '';
          };
        }
      );
}

