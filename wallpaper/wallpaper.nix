{ config, lib, pkgs, ... }:

let
  # Use the upstream CUDA wheel: building ONNX Runtime with CUDA from source
  # is expensive, and the standard nixpkgs Python package is CPU-only.
  cuda = pkgs.cudaPackages_12;
  gpuRuntime = pkgs.python3Packages.buildPythonPackage {
    pname = "onnxruntime-gpu";
    version = "1.24.4";
    format = "wheel";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/be/4e/56d11203d7a35e7d6a5ea735f5fecb8673537038c07323e8d3090a896547/onnxruntime_gpu-1.24.4-cp313-cp313-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256-u9qnP5BV+yoXdCXtvtZRoYQ6Yjn51UMOKE9OX2VECjM=";
    };
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [
      pkgs.stdenv.cc.cc.lib pkgs.zlib
      cuda.cuda_cudart cuda.libcublas cuda.libcurand cuda.libcufft
      cuda.cudnn cuda.cuda_nvrtc
    ];
    # We only use CUDA, not the optional TensorRT execution provider.
    postInstall = ''
      rm -f "$out"/lib/python*/site-packages/onnxruntime/capi/libonnxruntime_providers_tensorrt.so
    '';
    autoPatchelfIgnoreMissingDeps = [ "libcuda.so.1" ];
    pythonRemoveDeps = [ "flatbuffers" "protobuf" "sympy" ];
    dependencies = with pkgs.python3Packages; [ coloredlogs numpy packaging ];
    pythonImportsCheck = [ "onnxruntime" ];
  };
  outlinePython = pkgs.python3.withPackages (ps: [
    gpuRuntime ps.numpy ps.pillow ps.opencv4
  ]);
  model = pkgs.fetchurl {
    name = "birefnet-lite-dynamic.onnx";
    url = "https://huggingface.co/senty-au/BiRefNet_lite-ONNX-dynamic/resolve/173d635935b93839608b9b9039da8d1d212471e9/onnx/model.onnx";
    hash = "sha256-Hg2kLw/eAQ4y6Ti604hFfs7+NYBv3p2SNCGZeGGuk5E=";
  };
  halfModel = pkgs.runCommand "birefnet-general-lite-fp16.onnx" {
    nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.onnx ps.onnxconverter-common ])) ];
  } ''
    python3 ${./convert_model.py} ${model} "$out"
  '';
  outline = pkgs.writeShellApplication {
    name = "wallpaper-outline";
    text = ''
      export WALLPAPER_MODEL=${halfModel}
      export WALLPAPER_DIR="''${WALLPAPER_DIR:-${config.home.homeDirectory}/Pictures/Wallpapers}"
      export LD_LIBRARY_PATH="/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      exec ${outlinePython}/bin/python3 ${./outline.py} "$@"
    '';
  };
  library = pkgs.writeShellApplication {
    name = "wallpaper-library";
    runtimeInputs = [ pkgs.imagemagick ];
    text = ''
      export WALLPAPER_DIR="''${WALLPAPER_DIR:-${config.home.homeDirectory}/Pictures/Wallpapers}"
      exec ${pkgs.python3}/bin/python3 ${./library.py} "$@"
    '';
  };
  setWallpaper = pkgs.writeShellApplication {
    name = "wallpaper-set";
    runtimeInputs = [ pkgs.awww ];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./library.py} set "$@"
    '';
  };
  check = pkgs.writeShellApplication {
    name = "wallpaper-check";
    runtimeInputs = [ pkgs.imagemagick ];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./test_library.py} ${./library.py} "$@"
    '';
  };
in
{
  # Installs the client and runs the daemon as a user service.
  # Hyprland explicitly starts it because this session does not activate
  # graphical-session.target (see hyprland/hyprland.lua).
  services.awww.enable = true;
  home.packages = [ library setWallpaper check ]
    ++ lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [ outline ];
}
