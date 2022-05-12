{ pkgs, lib, fetchFromGitHub, python3Packages, qt5 }:

python3Packages.buildPythonApplication rec {
  pname = "opcua-client-gui";
  version = "cd96cc60e783c8f91b0cecd64573d296c2f94d0c";

  src = fetchFromGitHub {
    owner = "FreeOpcUa";
    repo = pname;
    rev = version;
    sha256 = "sha256-+QE/IaRqiFPIDKItUTZDMycpSK9J1BVRsCZa9lN5aqs=";
  };

  propagatedBuildInputs = [
    python3Packages.pip python3Packages.pyqt5 qt5.qtwayland
  ];

  nativeBuildInputs = [ qt5.wrapQtAppsHook ];

  # preFixup = ''
    # makeWrapperArgs+=("''${qtWrapperArgs[@]}")
  # '';

  # checkInputs = with python3Packages; [
    # pytest
    # pytest-xvfb
    # pytest-mock
    # pytest-cov
    # pytest-repeat
    # pytest-qt
  # ];

  # checkPhase = ''
    # pytest --no-xvfb
  # '';

  # requires X server
  # doCheck = false;

  # meta = with lib; {
    # description = "CadQuery GUI editor based on PyQT";
    # homepage = "https://github.com/CadQuery/CQ-editor";
    # license = licenses.asl20;
  # };

}
