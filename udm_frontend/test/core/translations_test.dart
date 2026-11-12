import 'package:flutter_test/flutter_test.dart';
import 'package:udm_frontend/app/core/localization/app_translations.dart';

void main() {
  test('English copy is returned untouched', () {
    expect(AppTranslations.localize('Look up any verse', 'en'), 'Look up any verse');
  });

  test('a label is translated before its widget shouts it', () {
    // Eyebrow uppercases what it renders, so the lookup has to survive that.
    expect(
      AppTranslations.localize('LOOK UP ANY VERSE', 'fr'),
      'CHERCHEZ N’IMPORTE QUEL VERSET',
    );
  });

  test('the reason a version cannot be printed is translated with its name', () {
    expect(
      AppTranslations.localize('New International Version · authorized link only', 'fr'),
      'New International Version · lien autorisé uniquement',
    );
    expect(
      AppTranslations.localize('English Standard Version · needs a key', 'fr'),
      'English Standard Version · clé requise',
    );
  });

  test('authorized link labels keep the version the student asked for', () {
    expect(
      AppTranslations.localize('Open New International Version on Bible Gateway', 'fr'),
      'Ouvrir New International Version sur Bible Gateway',
    );
  });

  test('an offline copy is still an offline copy in either language', () {
    expect(
      AppTranslations.localize('Offline copy · saved on this device', 'fr'),
      'Copie hors ligne · enregistrée sur cet appareil',
    );
  });

  test('the resource list keeps its numbering in French', () {
    expect(AppTranslations.localize('GUIDED READING', 'fr'), 'LECTURE GUIDÉE');
    expect(AppTranslations.localize('Find resources on', 'fr'), 'Trouver des ressources sur');
    expect(AppTranslations.localize('8 steps', 'fr'), '8 étape(s)');
    expect(AppTranslations.localize('Step 3', 'fr'), 'Étape 3');
    expect(AppTranslations.localize('Starting point', 'fr'), 'Point de départ');
  });

  test('a guide header keeps the ministry title and translates the position', () {
    // The part before the separator is server content, already in French, and
    // the Eyebrow that shows it shouts the whole line.
    expect(
      AppTranslations.localize('RECEVOIR CHRIST · STEP 2 OF 5', 'fr'),
      'RECEVOIR CHRIST · ÉTAPE 2 SUR 5',
    );
    expect(
      AppTranslations.localize('NOUVEAU CROYANT · STARTING POINT', 'fr'),
      'NOUVEAU CROYANT · POINT DE DÉPART',
    );
  });

  test('the Learn tab is named and counted in French', () {
    expect(AppTranslations.localize('Watch and listen', 'fr'), 'Regarder et écouter');
    // The tab's header is an Eyebrow, so it arrives already shouted.
    expect(AppTranslations.localize('WATCH AND LISTEN', 'fr'), 'REGARDER ET ÉCOUTER');
    expect(AppTranslations.localize('IN ORDER', 'fr'), 'DANS L’ORDRE');
    expect(AppTranslations.localize('2 recordings', 'fr'), '2 enregistrement(s)');
    expect(AppTranslations.localize('1 recording', 'fr'), '1 enregistrement(s)');
  });

  test('a recording page keeps its times and its states in French', () {
    expect(AppTranslations.localize('Resume 3:00', 'fr'), 'Reprendre à 3:00');
    expect(
      AppTranslations.localize('Continuing from 3:00. Press play where you stopped.', 'fr'),
      'Vous vous êtes arrêté à 3:00. Appuyez sur lecture pour reprendre.',
    );
    expect(AppTranslations.localize('Watched', 'fr'), 'Vu');
    expect(AppTranslations.localize('File', 'fr'), 'Fichier');
    expect(AppTranslations.localize('Play on YouTube', 'fr'), 'Lire sur YouTube');
    expect(AppTranslations.localize('Mark watched', 'fr'), 'Marquer comme vu');
  });

  test('a note answers in French whether it was kept or lost', () {
    expect(AppTranslations.localize('Take a note', 'fr'), 'Prendre une note');
    expect(AppTranslations.localize('Note saved', 'fr'), 'Note enregistrée');
    expect(AppTranslations.localize('Note deleted', 'fr'), 'Note supprimée');
    expect(
      AppTranslations.localize('Kept on your account, for you alone.', 'fr'),
      'Gardée sur votre compte, pour vous seul.',
    );
  });

  test('an offline recording says so on the recording page and on its shelf', () {
    // Two different surfaces, two different sentences: a student needs to know
    // which of the ministry's copies has gone stale.
    expect(
      AppTranslations.localize('Offline copy of this shelf', 'fr'),
      'Copie hors ligne de cette rubrique',
    );
    expect(
      AppTranslations.localize('Offline copy of this recording', 'fr'),
      'Copie hors ligne de cet enregistrement',
    );
  });
}
