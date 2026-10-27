// Darth Vader's Lightsaber – item name and description (Codeware localization)
module SaberDarthVader.Localization
import Codeware.Localization.*

public class SaberVader_LocalizationProvider extends ModLocalizationProvider {
  public func GetPackage(language: CName) -> ref<ModLocalizationPackage> {
    switch language {
      case n"de-de":
        return new SaberVader_German();
      default:
        return new SaberVader_English();
    }
  }

  public func GetFallback() -> CName {
    return n"en-us";
  }
}

public class SaberVader_English extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    this.Text("Saber-Vader-Name", "Darth Vader's Lightsaber");
    this.Text("Saber-Vader-Desc", "The red-bladed lightsaber of the Sith Lord Darth Vader. An elegant weapon for a more civilized age.");
  }
}

public class SaberVader_German extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    this.Text("Saber-Vader-Name", "Darth Vader's Lightsaber");   // name stays English
    this.Text("Saber-Vader-Desc", "Das rote Lichtschwert des Sith-Lords Darth Vader. Eine elegante Waffe aus zivilisierteren Tagen.");
  }
}
