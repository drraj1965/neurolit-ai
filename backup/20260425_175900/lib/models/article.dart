class Article {
  final String title;
  final String abstractText;
  final String journal;
  final String date;
  final String authors;
  final String pmid;
  final String link;

  final String publicationType;
  final bool isFree;
  final bool isPMC;

  // NEW
  final String pmcId;
  final bool canDownloadFullText;

  Article({
    required this.title,
    required this.abstractText,
    required this.journal,
    required this.date,
    required this.authors,
    required this.pmid,
    required this.link,
    this.publicationType = '',
    this.isFree = false,
    this.isPMC = false,
    this.pmcId = '',
    this.canDownloadFullText = false,
  });
}