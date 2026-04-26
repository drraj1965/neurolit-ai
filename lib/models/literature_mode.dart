enum LiteratureMode {
  medical,
  engineering,
}

LiteratureMode literatureModeFromValue(String value) {
  switch (value) {
    case 'engineering':
      return LiteratureMode.engineering;
    case 'medical':
    default:
      return LiteratureMode.medical;
  }
}

extension LiteratureModeX on LiteratureMode {
  String get storageValue {
    switch (this) {
      case LiteratureMode.medical:
        return 'medical';
      case LiteratureMode.engineering:
        return 'engineering';
    }
  }

  String get displayName {
    switch (this) {
      case LiteratureMode.medical:
        return 'Medical';
      case LiteratureMode.engineering:
        return 'Engineering';
    }
  }

  String get workspaceFolderName {
    switch (this) {
      case LiteratureMode.medical:
        return 'Medical';
      case LiteratureMode.engineering:
        return 'Engineering';
    }
  }

  String get sessionFilePrefix {
    switch (this) {
      case LiteratureMode.medical:
        return 'abstracts';
      case LiteratureMode.engineering:
        return 'EngineeringSession';
    }
  }

  String get searchHint {
    switch (this) {
      case LiteratureMode.medical:
        return 'Search PubMed topics';
      case LiteratureMode.engineering:
        return 'Search engineering literature';
    }
  }
}
