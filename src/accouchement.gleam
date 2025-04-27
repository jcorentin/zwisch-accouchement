import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option, None}
import gleam/string

pub type Raison {
  RaisonProposee(String)
  RaisonLibre(String)
  RaisonNone
}

pub fn encode_raison(raison: Raison) -> String {
  case raison {
    RaisonProposee(choice) -> choice
    RaisonLibre(choice) -> choice
    RaisonNone -> ""
  }
}

pub type Accouchement {
  Accouchement(
    user: String,
    poste_chef: Option(String),
    moment: Option(String),
    instrument: Option(String),
    autonomie: Option(String),
    raison: Raison,
  )
}

pub fn empty(user_id: String) -> Accouchement {
  Accouchement(
    user: user_id,
    poste_chef: None,
    moment: None,
    instrument: None,
    autonomie: None,
    raison: RaisonNone,
  )
}

pub fn decode() -> decode.Decoder(Accouchement) {
  use user <- decode.field("user", decode.string)
  use poste_chef <- decode.field("poste_chef", decode.string)
  use moment <- decode.field("moment", decode.string)
  use instrument <- decode.field("instrument", decode.string)
  use autonomie <- decode.field("autonomie", decode.string)
  use raison <- decode.field("autonomie_raison", decode.string)
  let raisons_proposees = [
    "geste_difficile", "situation_urgence", "manque_confiance",
    "changement_instrument", "cas_particulier", "guidance_technique",
    "manque_experience", "changement_instrument", "execution_rapide",
    "niveau_interne", "environnement_favorable", "gestes_interne",
  ]
  let is_raison_proposee = list.contains(raisons_proposees, raison)
  let raison = case raison {
    "" -> RaisonNone
    raison if is_raison_proposee -> RaisonProposee(raison)
    raison -> RaisonLibre(raison)
  }
  decode.success(Accouchement(
    user:,
    poste_chef: string.to_option(poste_chef),
    moment: string.to_option(moment),
    instrument: string.to_option(instrument),
    autonomie: string.to_option(autonomie),
    raison:,
  ))
}

pub fn encode(acc: Accouchement) -> String {
  let to_string = fn(opt) { option.unwrap(opt, "") |> json.string }
  json.object([
    #("user", json.string(acc.user)),
    #("poste_chef", to_string(acc.poste_chef)),
    #("moment", to_string(acc.moment)),
    #("instrument", to_string(acc.instrument)),
    #("autonomie", to_string(acc.autonomie)),
    #("autonomie_raison", acc.raison |> encode_raison |> json.string),
  ])
  |> json.to_string()
}

pub fn validate(
  acc: Accouchement,
) -> Result(Accouchement, List(#(String, String))) {
  let validate_fields =
    [
      #("poste_chef", acc.poste_chef),
      #("moment", acc.moment),
      #("instrument", acc.instrument),
      #("autonomie", acc.autonomie),
    ]
    |> list.map(fn(item) {
      let #(name, value) = item
      option.to_result(value, #(name, "empty_error"))
    })
  let validate_raison = case acc.raison {
    RaisonNone -> Error(#("autonomie_raison", "empty_error"))
    RaisonLibre("") -> Error(#("autonomie_raison", "empty_other_error"))
    _ -> Ok("")
  }

  let errors =
    [validate_raison, ..validate_fields]
    |> list.filter_map(fn(item) {
      case item {
        Error(err) -> Ok(err)
        Ok(_) -> Error(Nil)
      }
    })
  case list.is_empty(errors) {
    True -> Ok(acc)
    False -> Error(errors)
  }
}
