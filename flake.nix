{
  description = "rits — NixOS + Home Manager";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      # Keep HM on the same nixpkgs as the system to avoid version skew.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # AGS shell toolchain
    astal = {
      url = "github:aylur/astal";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ags = {
      url = "github:aylur/ags";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.astal.follows = "astal";
    };
  };
  outputs = {
    nixpkgs,
    home-manager,
    ...
  } @ inputs: {
    nixosConfigurations.rits = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./nixos/configuration.nix
        home-manager.nixosModules.home-manager
        {
          # Reuse the system's nixpkgs + allowUnfree / insecure settings.
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          # If a live file is in the way on first activation, rename it
          # to <file>.backup instead of aborting the whole rebuild.
          home-manager.backupFileExtension = "backup";
          # Make flake inputs available inside home.nix
          home-manager.extraSpecialArgs = {inherit inputs;};
          home-manager.users.si = import ./nixos/home.nix;
        }
      ];
    };
  };
}
