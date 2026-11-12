import 'package:get/get.dart';

/// UI copy for the languages currently supported by the app.
/// Server-authored content is localized by the API when a matching translation
/// has been entered by the ministry team.
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en': _english,
        'fr': _french,
      };

  static const Map<String, String> _english = {};

  /// Eyebrows and pills are uppercased by their widget before they reach here,
  /// so an exact key lookup would miss every one of them. This index lets a
  /// shouted label still find its copy, which is then shouted in turn.
  static final Map<String, String> _shouted = {
    for (final entry in _french.entries) entry.key.toUpperCase(): entry.value,
  };

  static String localize(String value, String languageCode) {
    if (languageCode != 'fr') return value;
    final exact = _french[value];
    if (exact != null) return exact;
    if (value == value.toUpperCase()) {
      final shouted = _shouted[value];
      if (shouted != null) return shouted.toUpperCase();
    }
    final day = RegExp(r'^Day (\d+)$').firstMatch(value);
    if (day != null) return 'Jour ${day.group(1)}';
    final year = RegExp(r'^Year (\d+)$').firstMatch(value);
    if (year != null) return 'Année ${year.group(1)}';
    final minutes = RegExp(r'^(\d+) min read$').firstMatch(value);
    if (minutes != null) return '${minutes.group(1)} min de lecture';
    final members = RegExp(r'^(\d+) members$').firstMatch(value);
    if (members != null) return '${members.group(1)} membres';
    final days = RegExp(r'^(\d+) days?$').firstMatch(value);
    if (days != null) return '${days.group(1)} jour(s)';
    final recordings = RegExp(r'^(\d+) recordings?$').firstMatch(value);
    if (recordings != null) return '${recordings.group(1)} enregistrement(s)';
    final resume = RegExp(r'^Resume (\d{1,2}:\d{2}(?::\d{2})?)$').firstMatch(value);
    if (resume != null) return 'Reprendre à ${resume.group(1)}';
    final continuing = RegExp(
      r'^Continuing from (\d{1,2}:\d{2}(?::\d{2})?)\. Press play where you stopped\.$',
    ).firstMatch(value);
    if (continuing != null) {
      return 'Vous vous êtes arrêté à ${continuing.group(1)}. Appuyez sur lecture pour reprendre.';
    }
    final step = RegExp(r'^Step (\d+)$').firstMatch(value);
    if (step != null) return 'Étape ${step.group(1)}';
    final steps = RegExp(r'^(\d+) steps?$').firstMatch(value);
    if (steps != null) return '${steps.group(1)} étape(s)';
    final interestLimit = RegExp(r'^Choose at most (\d+) interests\.$').firstMatch(value);
    if (interestLimit != null) return 'Choisissez au maximum ${interestLimit.group(1)} centres d’intérêt.';
    final privateChanges = RegExp(r'^(\d+) private change\(s\) waiting to sync\. Pull to refresh when you are online\.$').firstMatch(value);
    if (privateChanges != null) {
      return '${privateChanges.group(1)} modification(s) privée(s) en attente de synchronisation. Actualisez pour synchroniser lorsque vous êtes en ligne.';
    }
    final range = RegExp(r'^Between (\d+) and (\d+)\.$').firstMatch(value);
    if (range != null) return 'Entre ${range.group(1)} et ${range.group(2)}.';
    final interestHelp = RegExp(r'^Used to suggest devotion and group content\. Up to (\d+)\.$').firstMatch(value);
    if (interestHelp != null) {
      return 'Utilisés pour suggérer des méditations et des groupes. Jusqu’à ${interestHelp.group(1)}.';
    }
    if (value.startsWith('Offline copy · ')) {
      return 'Copie hors ligne · ${value.substring('Offline copy · '.length)}';
    }
    if (value.startsWith('Waiting for review · ')) {
      return 'En attente de révision · ${localize(value.substring('Waiting for review · '.length), languageCode)}';
    }
    // The version picker appends why a text cannot be printed by this build.
    for (final entry in const <String, String>{
      'authorized link only': 'lien autorisé uniquement',
      'needs a key': 'clé requise',
    }.entries) {
      if (value.endsWith(' · ${entry.key}')) {
        return '${value.substring(0, value.length - entry.key.length - 3)} · ${entry.value}';
      }
    }
    // A guide's reader header leads with the ministry's own title, so only the
    // position behind the separator is app copy. An Eyebrow shouts the whole
    // line before it reaches here, which is the form this matches.
    if (value.endsWith(' · STARTING POINT')) {
      return '${value.substring(0, value.length - 'STARTING POINT'.length)}POINT DE DÉPART';
    }
    final guideStep = RegExp(r'^(.+) · STEP (\d+) OF (\d+)$').firstMatch(value);
    if (guideStep != null) {
      return '${guideStep.group(1)} · ÉTAPE ${guideStep.group(2)} SUR ${guideStep.group(3)}';
    }
    final authorized = RegExp(r'^Open (.+) on (Bible Gateway|YouVersion)$').firstMatch(value);
    if (authorized != null) {
      return 'Ouvrir ${authorized.group(1)} sur ${authorized.group(2)}';
    }
    if (value.endsWith(' prayer')) {
      return '${localize(value.substring(0, value.length - 7), languageCode)} prière';
    }
    if (value.startsWith('Good morning')) return value.replaceFirst('Good morning', 'Bonjour');
    if (value.startsWith('Good afternoon')) return value.replaceFirst('Good afternoon', 'Bon après-midi');
    if (value.startsWith('Good evening')) return value.replaceFirst('Good evening', 'Bonsoir');
    if (value.startsWith('Play ')) return value.replaceFirst('Play ', 'Lire ');
    if (value.contains(' members')) return value.replaceAll(' members', ' membres');
    return value;
  }

  static const Map<String, String> _french = {
    'Home': 'Accueil',
    'Bible': 'Bible',
    'Learn': 'Apprendre',
    'Community': 'Communauté',
    'Profile': 'Profil',
    'Devotions': 'Méditations',
    'Read through': 'Lecture suivie',
    'Series the ministry team is publishing now.': 'Les séries publiées en ce moment par l’équipe du ministère.',
    'Saved on this device. Pull to refresh when you are online.': 'Enregistrées sur cet appareil. Actualisez lorsque vous êtes en ligne.',
    'No series published yet': 'Aucune série publiée',
    'When the ministry team publishes a set of devotionals it appears here as a series.': 'Les méditations publiées par l’équipe du ministère apparaîtront ici sous forme de série.',
    'Reading order': 'Ordre de lecture',
    'Introduction': 'Introduction',
    'Nothing published in this series yet': 'Rien de publié dans cette série pour le moment',
    'The ministry team has not released a day of this series. Check back soon.': 'L’équipe du ministère n’a pas encore publié de jour pour cette série. Revenez bientôt.',
    'Offline copy of this series': 'Copie hors ligne de cette série',
    'Choose language': 'Choisir la langue',
    'French': 'Français',
    'Today': 'Aujourd’hui',
    'Curated by the ministry team': 'Sélectionné par l’équipe du ministère',
    'No devotion scheduled': 'Aucune méditation prévue',
    'Check back after the next publishing window.': 'Revenez après la prochaine publication.',
    'Latest reading': 'Dernières lectures',
    'Memory verse': 'Verset à mémoriser',
    'Find resources on': 'Trouver des ressources sur',
    'Guided reading': 'Lecture guidée',
    'Short guides for the questions students actually ask':
        'De courts guides pour les questions que les étudiants posent vraiment',
    'Resources': 'Ressources',
    'Guide': 'Guide',
    'Step order': 'Ordre des étapes',
    'Starting point': 'Point de départ',
    'Nothing published in this guide yet': 'Aucune étape publiée dans ce guide pour le moment',
    'The ministry team has not released a step of this guide. Check back soon.':
        'L’équipe du ministère n’a pas encore publié d’étape dans ce guide. Revenez bientôt.',
    'Offline copy of this guide': 'Copie hors ligne de ce guide',
    'Step unavailable': 'Étape indisponible',
    'This step is no longer published.': 'Cette étape n’est plus publiée.',
    'Video': 'Vidéo',
    'Watch': 'Regarder',
    'Watch this step': 'Voir cette étape',
    'Opens in your browser, hosted by the ministry.': 'S’ouvre dans votre navigateur, hébergé par le ministère.',
    'Video unavailable': 'Vidéo indisponible',
    'This step has no safe video link.': 'Cette étape ne possède pas de lien vidéo sûr.',
    'No app could open this video.': 'Aucune application n’a pu ouvrir cette vidéo.',
    // The Learn tab: the ministry's shelves of teaching recordings.
    'Watch and listen': 'Regarder et écouter',
    'Teaching recordings the ministry publishes on YouTube.':
        'Les enregistrements d’enseignement publiés par le ministère sur YouTube.',
    'No recordings published yet': 'Aucun enregistrement publié pour le moment',
    'When the ministry team puts a teaching recording on a shelf it appears here.':
        'Dès que l’équipe du ministère place un enregistrement sur une rubrique, il apparaît ici.',
    'In order': 'Dans l’ordre',
    'Nothing released on this shelf yet': 'Rien de publié sur cette rubrique pour le moment',
    'The ministry team has not published a recording here. Check back soon.':
        'L’équipe du ministère n’a pas encore publié d’enregistrement ici. Revenez bientôt.',
    'Offline copy of this shelf': 'Copie hors ligne de cette rubrique',
    'Offline copy of this recording': 'Copie hors ligne de cet enregistrement',
    'File': 'Fichier',
    'Watched': 'Vu',
    'Open': 'Ouvrir',
    'Play on YouTube': 'Lire sur YouTube',
    'Recording unavailable': 'Enregistrement indisponible',
    'This recording is no longer published.': 'Cet enregistrement n’est plus publié.',
    'Mark watched': 'Marquer comme vu',
    'Take a note': 'Prendre une note',
    'Your note': 'Votre note',
    'Close note': 'Fermer la note',
    'Save note': 'Enregistrer la note',
    'Share': 'Partager',
    'Download': 'Télécharger',
    'Delete': 'Supprimer',
    'What did this teaching bring you?': 'Qu’est-ce que cet enseignement vous a apporté ?',
    'Only you and your account can see this.': 'Seuls vous et votre compte pouvez le voir.',
    'Note saved': 'Note enregistrée',
    'Kept on your account, for you alone.': 'Gardée sur votre compte, pour vous seul.',
    'Note deleted': 'Note supprimée',
    'Your note on this recording is gone.': 'Votre note sur cet enregistrement a disparu.',
    'Sign in to keep your notes and your place in a recording.':
        'Connectez-vous pour conserver vos notes et votre place dans un enregistrement.',
    'The ministry has not put this recording online yet. Its write-up is here to read, and the teaching arrives as soon as staff attach it.':
        'Le ministère n’a pas encore mis cet enregistrement en ligne. Son texte reste à lire ici, et l’enseignement arrivera dès que l’équipe l’aura joint.',
    'This build has no video engine for the inline player.':
        'Cette version de l’application ne contient pas de moteur vidéo pour le lecteur intégré.',
    'This recording will not play here': 'Cet enregistrement ne peut pas être lu ici',
    'The owner of this recording does not allow it to play inside other apps.':
        'Le propriétaire de cet enregistrement n’autorise pas sa lecture dans d’autres applications.',
    'YouTube has nothing at this address — the recording may be private or taken down. Tell the ministry team so the link can be fixed.':
        'YouTube ne trouve rien à cette adresse — l’enregistrement est peut-être privé ou retiré. Prévenez l’équipe du ministère pour que le lien soit corrigé.',
    'The video engine on this device cannot play this recording.':
        'Le moteur vidéo de cet appareil ne peut pas lire cet enregistrement.',
    'YouTube did not play this recording.': 'YouTube n’a pas lu cet enregistrement.',
    'Could not share': 'Impossible de partager',
    'No sharing app answered. Copy the link from YouTube instead.':
        'Aucune application de partage n’a répondu. Copiez plutôt le lien depuis YouTube.',
    'Could not open the file': 'Impossible d’ouvrir le fichier',
    'No app on this device can take this download.':
        'Aucune application de cet appareil ne peut prendre ce téléchargement.',
    'Could not open YouTube': 'Impossible d’ouvrir YouTube',
    'No app on this device could open this recording.':
        'Aucune application de cet appareil n’a pu ouvrir cet enregistrement.',
    'Sign in': 'Se connecter',
    'Create an account': 'Créer un compte',
    'Grow in His Word.': 'Grandir dans sa Parole.',
    'Try again': 'Réessayer',
    'Nothing here yet': 'Rien pour le moment',
    'We could not load this': 'Impossible de charger ce contenu',
    'Check your connection and try again.': 'Vérifiez votre connexion et réessayez.',
    'Content published by the ministry team will appear here.': 'Le contenu publié par l’équipe du ministère apparaîtra ici.',
    'Offline copy': 'Copie hors ligne',
    'VERSE OF THE DAY': 'VERSET DU JOUR',
    'OPEN TODAY\'S DEVOTION': 'OUVRIR LA MÉDITATION DU JOUR',
    'Today\'s devotion': 'Méditation du jour',
    'Reflect': 'Réfléchir',
    'Live it out': 'Mettre en pratique',
    'Pray': 'Prier',
    'Memorise': 'Mémoriser',
    'Marked as read': 'Marqué comme lu',
    'Mark as read': 'Marquer comme lu',
    'Saving…': 'Enregistrement…',
    'Sign in to keep this in your reading history.': 'Connectez-vous pour conserver cette lecture dans votre historique.',
    'Verse actions': 'Actions sur le verset',
    'Bookmark': 'Ajouter aux favoris',
    'Add private note': 'Ajouter une note privée',
    'My saved verses and notes': 'Mes versets et notes enregistrés',
    'Remove bookmark': 'Retirer des favoris',
    'Delete note': 'Supprimer la note',
    'Keep your bookmarks and notes': 'Conservez vos favoris et vos notes',
    'Mark complete': 'Marquer comme terminé',
    'Translation license and source': 'Licence et source de la traduction',
    'Private note': 'Note privée',
    'Write a note for yourself': 'Écrivez une note personnelle',
    'Cancel': 'Annuler',
    'Save': 'Enregistrer',
    'Close': 'Fermer',
    'Done': 'Terminé',
    'Submitting…': 'Envoi…',
    'Mark memorized': 'Marquer comme mémorisé',
    'Memorized': 'Mémorisé',
    'Saved': 'Enregistré',
    'This verse is on your list to keep.': 'Ce verset est sur votre liste à garder.',
    'Membership requests': 'Demandes d’adhésion',
    'Fellowships': 'Groupes chrétiens',
    'Request to join': 'Demander à rejoindre',
    'Membership request sent': 'Demande d’adhésion envoyée',
    'You are a member': 'Vous êtes membre',
    'Prayer requests to review': 'Demandes de prière à examiner',
    'Approve': 'Approuver',
    'Decline': 'Refuser',
    'Share with group': 'Partager avec le groupe',
    'Join online event': 'Participer à l’événement en ligne',
    'Registered': 'Inscrit',
    'Full': 'Complet',
    'Register': 'S’inscrire',
    'Write a prayer request': 'Écrire une demande de prière',
    'Sign in to write a private prayer or share one with consent.': 'Connectez-vous pour écrire une prière privée ou la partager avec consentement.',
    'Prayer request': 'Demande de prière',
    'Only me': 'Moi uniquement',
    'My group': 'Mon groupe',
    'Community prayer wall': 'Mur de prière communautaire',
    'Join a group before sharing a group prayer request.': 'Rejoignez un groupe avant d’y partager une demande de prière.',
    'Delete my request': 'Supprimer ma demande',
    'Waiting for review': 'En attente de révision',
    'Sign out': 'Se déconnecter',
    'Sign out?': 'Voulez-vous vous déconnecter ?',
    'Your content stays readable. Your saved profile and progress stay on your account.': 'Votre contenu restera accessible. Votre profil et votre progression resteront enregistrés sur votre compte.',
    'Not signed in': 'Vous n’êtes pas connecté',
    'Devotions, verses and articles stay readable without an account. Sign in to save your campus details and your reading progress.': 'Les méditations, versets et articles restent accessibles sans compte. Connectez-vous pour enregistrer les informations de votre campus et votre progression.',
    'Your details': 'Vos informations',
    'Saved to your account on the UDM service.': 'Enregistrées sur votre compte UDM.',
    'University': 'Université',
    'Campus': 'Campus',
    'Course': 'Filière',
    'Year of study': 'Année d’études',
    'Church': 'Église',
    'Where you live': 'Lieu de résidence',
    'Bible preference': 'Version biblique préférée',
    'Edit details': 'Modifier les informations',
    'Not added': 'Non renseigné',
    'Edit your details': 'Modifier vos informations',
    'Full name': 'Nom complet',
    'Phone number': 'Numéro de téléphone',
    'Church or fellowship': 'Église ou groupe chrétien',
    'City': 'Ville',
    'Country': 'Pays',
    'Gender': 'Genre',
    'Male': 'Homme',
    'Female': 'Femme',
    'Prefer not to say': 'Je préfère ne pas répondre',
    'Interests': 'Centres d’intérêt',
    'Used to suggest devotion and group content. Up to {max}.': 'Utilisés pour suggérer des méditations et des groupes. Jusqu’à {max}.',
    'Add an interest': 'Ajouter un centre d’intérêt',
    'Check the fields marked above before saving.': 'Vérifiez les champs indiqués avant d’enregistrer.',
    'Save changes': 'Enregistrer les modifications',
    'Between {min} and {max}.': 'Entre {min} et {max}.',
    'Email verification is not available in this build yet.': 'La vérification de l’adresse e-mail n’est pas encore disponible.',
    'Checking your session…': 'Vérification de votre session…',
    'Your profile is on this device, but not loaded yet.': 'Votre profil est sur cet appareil, mais n’a pas encore été chargé.',
    'Sign in?': 'Se connecter ?',
    'Sign in required': 'Connexion requise',
    'Email': 'E-mail',
    'Password': 'Mot de passe',
    'Confirm password': 'Confirmer le mot de passe',
    'Welcome back': 'Bon retour',
    'Start your journey': 'Commencez votre parcours',
    'Start my journey': 'Commencer mon parcours',
    'Next': 'Suivant',
    'Back': 'Retour',
    'Skip': 'Passer',
    'Explore first': 'Explorer d’abord',
    'I already have an account': 'J’ai déjà un compte',
    'Create account': 'Créer un compte',
    'Creating account…': 'Création du compte…',
    'Signing in…': 'Connexion…',
    'Show password': 'Afficher le mot de passe',
    'Hide password': 'Masquer le mot de passe',
    'Enter your email address.': 'Saisissez votre adresse e-mail.',
    'That does not look like an email address.': 'Cette adresse e-mail ne semble pas valide.',
    'Tell us what to call you.': 'Indiquez votre nom.',
    'Use at most {max} characters.': 'Utilisez au maximum {max} caractères.',
    'Enter your password.': 'Saisissez votre mot de passe.',
    'Use at least {min} characters.': 'Utilisez au moins {min} caractères.',
    'The passwords do not match.': 'Les mots de passe ne correspondent pas.',
    'The connection took too long. Check your network and try again.': 'La connexion a pris trop de temps. Vérifiez votre réseau et réessayez.',
    'You appear to be offline. Showing what was last downloaded.': 'Vous semblez hors ligne. Voici le dernier contenu téléchargé.',
    'The request was cancelled.': 'La requête a été annulée.',
    'The server certificate could not be verified.': 'Le certificat du serveur n’a pas pu être vérifié.',
    'No connection to the UDM service. Showing what was last downloaded.': 'Connexion au service UDM impossible. Voici le dernier contenu téléchargé.',
    'Something went wrong.': 'Une erreur s’est produite.',
    'The request was rejected.': 'La requête a été refusée.',
    'Please sign in to continue.': 'Connectez-vous pour continuer.',
    'You do not have access to this.': 'Vous n’avez pas accès à ce contenu.',
    'We could not find that.': 'Élément introuvable.',
    'Too many requests. Please pause and try again shortly.': 'Trop de requêtes. Patientez un instant avant de réessayer.',
    'The service is temporarily unavailable.': 'Le service est temporairement indisponible.',
    'Article unavailable': 'Article indisponible',
    'This article is no longer published.': 'Cet article n’est plus publié.',
    'Reading': 'Lecture',
    'min read': 'min de lecture',
    'The backend could not connect to api.youversion.com. Check outbound HTTPS access and retry.': 'Le serveur n’a pas pu se connecter à api.youversion.com. Vérifiez l’accès HTTPS et réessayez.',
    'Know Christ. Grow in Christ. Make Disciples.': 'Connaître le Christ. Grandir dans le Christ. Faire des disciples.',
    'Available today': 'Disponible aujourd’hui',
    'This tab is intentionally empty until that phase ships.': 'Cet onglet sera disponible dans une prochaine version.',
    'An email address and a password are enough. Your campus details, reading progress and reflections are saved to your own account.': 'Une adresse e-mail et un mot de passe suffisent. Les informations de votre campus, votre progression et vos réflexions sont enregistrées dans votre compte.',
    'At least 10 characters, not a common word.': 'Au moins 10 caractères, sans mot courant.',
    'Sign in to keep your reading progress and profile in step across your devices. Nothing you write privately leaves your account.': 'Connectez-vous pour synchroniser votre progression et votre profil sur vos appareils. Vos notes privées restent dans votre compte.',
    'No licensed translations are available yet.': 'Aucune traduction autorisée n’est disponible pour le moment.',
    'Licensed Scripture': 'Texte biblique autorisé',
    'Find a translation': 'Rechercher une traduction',
    'Translation': 'Traduction',
    'Book': 'Livre',
    'Chapter': 'Chapitre',
    'Offline copy · saved on this device': 'Copie hors ligne · enregistrée sur cet appareil',
    'Look up any verse': 'Cherchez n’importe quel verset',
    'Reference': 'Référence',
    'John 3:16 · 1Jn 3:16-18 · Ps 23': 'Jean 3:16 · 1Jn 3:16-18 · Ps 23',
    'Go': 'Aller',
    'Version': 'Version',
    'Finding the passage…': 'Recherche du passage…',
    'Type a reference, for example John 3:16.': 'Saisissez une référence, par exemple Jean 3:16.',
    'Clear': 'Effacer',
    'Search any reference, or pick a translation to read through.': 'Cherchez n’importe quelle référence ou choisissez une traduction à lire.',
    'No translation has been synced into this deployment yet, so reading a whole chapter is not possible. Reference lookup still works and opens licensed versions on an authorized site.': 'Aucune traduction n’a encore été synchronisée dans cette installation : la lecture d’un chapitre entier n’est donc pas possible. La recherche de référence fonctionne toujours et ouvre les traductions autorisées sur un site habilité.',
    'Your saved verses and private notes will appear here.': 'Vos versets enregistrés et vos notes privées apparaîtront ici.',
    'Saved verse': 'Verset enregistré',
    'Sign in to sync them privately across your devices.': 'Connectez-vous pour les synchroniser en privé sur vos appareils.',
    'Reading plans': 'Plans de lecture',
    'Sign in to request membership in a group.': 'Connectez-vous pour demander à rejoindre un groupe.',
    'Request sent': 'Demande envoyée',
    'The group leader will review your request.': 'Le responsable du groupe examinera votre demande.',
    'Could not request membership': 'Impossible d’envoyer la demande d’adhésion',
    'Could not update request': 'Impossible de mettre à jour la demande',
    'Sign in to register for events.': 'Connectez-vous pour vous inscrire aux événements.',
    'You are on the event list.': 'Vous êtes inscrit à cet événement.',
    'Could not register': 'Impossible de vous inscrire',
    'Event link unavailable': 'Lien de l’événement indisponible',
    'This event does not have a safe online link.': 'Cet événement ne possède pas de lien en ligne sûr.',
    'No app could open this event.': 'Aucune application n’a pu ouvrir cet événement.',
    'Sign in to save a private prayer or share with others.': 'Connectez-vous pour enregistrer une prière privée ou la partager.',
    'Prayer saved': 'Prière enregistrée',
    'Only you can see it.': 'Vous seul pouvez la voir.',
    'It is waiting for the selected reviewers.': 'Elle attend l’examen des personnes choisies.',
    'Could not save prayer': 'Impossible d’enregistrer la prière',
    'Could not delete prayer': 'Impossible de supprimer la prière',
    'Could not review prayer': 'Impossible d’examiner la prière',
    'No campus directory entries have been published yet.': 'Aucun campus n’a encore été ajouté à l’annuaire.',
    'No discoverable groups are available yet.': 'Aucun groupe ouvert n’est disponible pour le moment.',
    'No upcoming events have been published yet.': 'Aucun événement à venir n’a encore été publié.',
    'No shared prayer requests are currently visible.': 'Aucune demande de prière partagée n’est visible pour le moment.',
    'What would you like prayer for?': 'Pour quel sujet souhaitez-vous demander la prière ?',
    'Who can see this?': 'Qui peut voir cette demande ?',
    'I consent to sharing this publicly after moderator review.': 'J’accepte le partage public après examen par un modérateur.',
    'I consent to sharing this with my group after leader review.': 'J’accepte le partage avec mon groupe après examen par son responsable.',
    'Devotion unavailable': 'Méditation indisponible',
    'This devotion is no longer published.': 'Cette méditation n’est plus publiée.',
    'Nothing published yet': 'Aucun contenu publié pour le moment',
    'Once the ministry team publishes a devotion or article it shows up here.': 'Les méditations et articles apparaîtront ici dès leur publication par l’équipe du ministère.',
    'Sign in to keep this reading, your progress and your details on your own account.': 'Connectez-vous pour enregistrer cette lecture, votre progression et vos informations dans votre compte.',
    'Peace be with you': 'Que la paix soit avec vous',
    'Sign in to keep memory verse progress.': 'Connectez-vous pour conserver votre progression de mémorisation.',
    'Could not save review': 'Impossible d’enregistrer la révision',
    'Scripture you actually finish': 'Des lectures bibliques que vous terminez',
    'Read a licensed Bible, take today\'s devotion, and memorise a verse. Notes and highlights stay yours.': 'Lisez une Bible autorisée, découvrez la méditation du jour et mémorisez un verset. Vos notes et surlignages restent privés.',
    'Discipleship, not downloads': 'La formation de disciples, pas les téléchargements',
    'Work through the ministry\'s teaching recordings, write what each one brought you, and follow a guided resource on the questions you actually ask.':
        'Suivez les enregistrements du ministère, notez ce que chacun vous a apporté et prenez un guide sur les questions que vous posez vraiment.',
    'Sent to your campus': 'Envoyés sur votre campus',
    'Share a teaching with a friend, work through a guide with someone new to the faith, and keep a verse ready for the day they ask you why.':
        'Partagez un enseignement avec un ami, suivez un guide avec quelqu’un qui débute la foi, et gardez un verset prêt pour le jour où l’on vous demandera pourquoi vous croyez.',
    'University Discipleship Mission': 'Mission de formation de disciples universitaires',
    'King James Version': 'Version King James',
    'World English Bible': 'Bible anglaise mondiale',
    'American Standard Version': 'Version American Standard',
    'Bible version': 'Version biblique',
    'Profile shown as last downloaded. You appear to be offline.': 'Le dernier profil téléchargé est affiché. Vous semblez hors ligne.',
    'Signed out on this device. The server could not be reached, so this session was not revoked there.': 'Vous êtes déconnecté de cet appareil. Le serveur étant inaccessible, la session n’a pas pu y être révoquée.',
    'Your session expired. Sign in again to continue.': 'Votre session a expiré. Reconnectez-vous pour continuer.',
    'Groups': 'Groupes',
    'Events': 'Événements',
    'Prayer': 'Prière',
    'Community group': 'Groupe communautaire',
    'Student': 'Étudiant',
    'Group': 'Groupe',
    'Sign in to save bookmarks to your account.': 'Connectez-vous pour enregistrer vos favoris dans votre compte.',
    'Verse added to your bookmarks.': 'Verset ajouté à vos favoris.',
    'Could not save bookmark': 'Impossible d’enregistrer le favori',
    'Saved for sync': 'Enregistré pour synchronisation',
    'Bookmark will sync when you are back online.': 'Le favori sera synchronisé lorsque vous serez de nouveau en ligne.',
    'Could not remove bookmark': 'Impossible de retirer le favori',
    'Bookmark removal will sync when you are back online.': 'Le retrait du favori sera synchronisé lorsque vous serez de nouveau en ligne.',
    'Sign in to keep private Bible notes.': 'Connectez-vous pour conserver vos notes bibliques privées.',
    'Saved privately': 'Enregistré en privé',
    'Your note is only visible to you.': 'Vous seul pouvez voir votre note.',
    'Could not save note': 'Impossible d’enregistrer la note',
    'Private note will sync when you are back online.': 'La note privée sera synchronisée lorsque vous serez de nouveau en ligne.',
    'Could not update note': 'Impossible de modifier la note',
    'Your change will sync when you are back online.': 'Votre modification sera synchronisée lorsque vous serez de nouveau en ligne.',
    'Could not remove note': 'Impossible de supprimer la note',
    'Note removal will sync when you are back online.': 'La suppression de la note sera synchronisée lorsque vous serez de nouveau en ligne.',
    'Sign in to save reading plan progress.': 'Connectez-vous pour enregistrer votre progression dans le plan de lecture.',
    'Reading progress will sync when you are back online.': 'Votre progression sera synchronisée lorsque vous serez de nouveau en ligne.',
    'Choose at most 12 interests.': 'Choisissez au maximum 12 centres d’intérêt.',
    'Between 1 and 13.': 'Entre 1 et 13.',
    'Use at most 150 characters.': 'Utilisez au maximum 150 caractères.',
    'Use at least 10 characters.': 'Utilisez au moins 10 caractères.',
    'Could not save progress': 'Impossible d’enregistrer la progression',
    'Pending': 'En attente',
    'private': 'privée',
    'group': 'groupe',
    'public': 'publique',
    'french': 'français',
    'Genesis': 'Genèse',
    'Exodus': 'Exode',
    'Leviticus': 'Lévitique',
    'Numbers': 'Nombres',
    'Deuteronomy': 'Deutéronome',
    'Joshua': 'Josué',
    'Judges': 'Juges',
    'Ruth': 'Ruth',
    '1 Samuel': '1 Samuel',
    '2 Samuel': '2 Samuel',
    '1 Kings': '1 Rois',
    '2 Kings': '2 Rois',
    '1 Chronicles': '1 Chroniques',
    '2 Chronicles': '2 Chroniques',
    'Ezra': 'Esdras',
    'Nehemiah': 'Néhémie',
    'Esther': 'Esther',
    'Job': 'Job',
    'Psalms': 'Psaumes',
    'Proverbs': 'Proverbes',
    'Ecclesiastes': 'Ecclésiaste',
    'Song of Solomon': 'Cantique des cantiques',
    'Isaiah': 'Ésaïe',
    'Jeremiah': 'Jérémie',
    'Lamentations': 'Lamentations',
    'Ezekiel': 'Ézéchiel',
    'Daniel': 'Daniel',
    'Hosea': 'Osée',
    'Joel': 'Joël',
    'Amos': 'Amos',
    'Obadiah': 'Abdias',
    'Jonah': 'Jonas',
    'Micah': 'Michée',
    'Nahum': 'Nahum',
    'Habakkuk': 'Habacuc',
    'Zephaniah': 'Sophonie',
    'Haggai': 'Aggée',
    'Zechariah': 'Zacharie',
    'Malachi': 'Malachie',
    'Matthew': 'Matthieu',
    'Mark': 'Marc',
    'Luke': 'Luc',
    'John': 'Jean',
    'Acts': 'Actes',
    'Romans': 'Romains',
    '1 Corinthians': '1 Corinthiens',
    '2 Corinthians': '2 Corinthiens',
    'Galatians': 'Galates',
    'Ephesians': 'Éphésiens',
    'Philippians': 'Philippiens',
    'Colossians': 'Colossiens',
    '1 Thessalonians': '1 Thessaloniciens',
    '2 Thessalonians': '2 Thessaloniciens',
    '1 Timothy': '1 Timothée',
    '2 Timothy': '2 Timothée',
    'Titus': 'Tite',
    'Philemon': 'Philémon',
    'Hebrews': 'Hébreux',
    'James': 'Jacques',
    '1 Peter': '1 Pierre',
    '2 Peter': '2 Pierre',
    '1 John': '1 Jean',
    '2 John': '2 Jean',
    '3 John': '3 Jean',
    'Jude': 'Jude',
    'Revelation': 'Apocalypse',
    'Use at most @max characters.': 'Utilisez au maximum @max caractères.',
    'Use at least @min characters.': 'Utilisez au moins @min caractères.',
    'Between @min and @max.': 'Entre @min et @max.',
    'Choose at most @max interests.': 'Choisissez au maximum @max centres d’intérêt.',
  };
}
