import components
import formal/form
import gleam/dynamic/decode.{type Decoder}
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import icons
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import pocketbase_sdk.{type PocketBase} as pb
import rsvp

// MAIN ------------------------------------------------------------------------

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

// MODEL -----------------------------------------------------------------------

const server_host = "127.0.0.1"

// let server_host = "192.168.1.46"

const server_port = 8090

fn init(_args: Nil) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      pb: pb.new(server_host, server_port),
      profil: empty_profil(),
      page: LoginPage,
    )
  let #(server, pb_effect) = pb.init(server_host, server_port)
  #(Model(..model, pb: server), effect.map(pb_effect, PocketBaseMsg))
}

type Model {
  Model(pb: PocketBase, profil: Profil, page: Page)
}

type Profil {
  Profil(name: Option(String), sexe: Option(String), semestre: Option(String))
}

fn empty_profil() {
  Profil(name: None, sexe: None, semestre: None)
}

fn decode_profil() -> Decoder(Profil) {
  use name <- decode.field("name", decode.string)
  use semestre <- decode.field("semestre", decode.string)
  use sexe <- decode.field("sexe", decode.string)
  decode.success(Profil(
    name: string.to_option(name),
    semestre: string.to_option(semestre),
    sexe: string.to_option(sexe),
  ))
}

fn encode_profil(profil: Profil) -> String {
  [
    #("name", profil.name),
    #("sexe", profil.sexe),
    #("semestre", profil.semestre),
  ]
  |> list.map(fn(item) {
    let #(key, value) = item
    option.map(value, fn(value) { #(key, json.string(value)) })
  })
  |> option.values
  |> json.object
  |> json.to_string
}

type Page {
  AccueilPage
  LoginPage
  AccouchementPage(#(Option(Profil), Accouchement))
  ProfilPage
}

fn page_name(page: Page) {
  case page {
    ProfilPage -> "Profil"
    AccueilPage -> "Accueil"
    AccouchementPage(_) -> "Accouchement"
    LoginPage -> "Login"
  }
}

type Raison {
  RaisonProposee(String)
  RaisonLibre(String)
  RaisonNone
}

fn encode_raison(raison: Raison) {
  case raison {
    RaisonProposee(choice) -> choice
    RaisonLibre(choice) -> choice
    RaisonNone -> ""
  }
}

type Accouchement {
  Accouchement(
    user: String,
    poste_chef: Option(String),
    moment: Option(String),
    instrument: Option(String),
    autonomie: Option(String),
    raison: Raison,
  )
}

fn empty_accouchement(user_id: String) {
  Accouchement(
    user: user_id,
    poste_chef: None,
    moment: None,
    instrument: None,
    autonomie: None,
    raison: RaisonNone,
  )
}

fn decode_accouchement() {
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

fn encode_accouchement(acc: Accouchement) {
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

fn validate_accouchement(acc: Accouchement) {
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

// UPDATE ----------------------------------------------------------------------

type LoginData {
  LoginData(username: String, password: String)
}

type Msg {
  PocketBaseMsg(pb.Msg)
  UserSubmittedLoginForm(Result(LoginData, form.Form))
  UserClickedDock(String)
  UserClickedLogout
  UserSubmittedProfil(Result(Profil, form.Form))
  ApiReturnedProfil(Result(Profil, rsvp.Error))
  UserSubmittedAccouchement(Result(#(Option(Profil), Accouchement), Nil))
  ApiReturnedAccouchement(Result(Accouchement, rsvp.Error))
  UserChangedSexe(String)
  UserChangedSemestre(String)
  UserChangedPosteChef(String)
  UserChangedMoment(String)
  UserChangedInstrument(String)
  UserChangedAutonomie(String)
  UserChangedRaison(String)
  UserChangedRaisonAutre(String)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserSubmittedLoginForm(Ok(login_data)) -> #(
      model,
      effect.map(
        pb.auth_with_password(
          model.pb,
          login_data.username,
          login_data.password,
        ),
        PocketBaseMsg,
      ),
    )
    UserSubmittedLoginForm(_) -> #(model, effect.none())

    UserChangedAutonomie(new_autonomie) -> {
      let assert AccouchementPage(#(profil, acc)) = model.page
      let new_acc =
        Accouchement(..acc, autonomie: Some(new_autonomie), raison: RaisonNone)
      #(
        Model(..model, page: AccouchementPage(#(profil, new_acc))),
        effect.none(),
      )
    }
    UserChangedRaison("autre") -> {
      let assert AccouchementPage(#(profil, acc)) = model.page
      let new_acc = Accouchement(..acc, raison: RaisonLibre(""))
      #(
        Model(..model, page: AccouchementPage(#(profil, new_acc))),
        effect.none(),
      )
    }
    UserChangedRaison(raison) -> {
      let assert AccouchementPage(#(profil, acc)) = model.page
      let new_acc = Accouchement(..acc, raison: RaisonProposee(raison))
      #(
        Model(..model, page: AccouchementPage(#(profil, new_acc))),
        effect.none(),
      )
    }

    UserSubmittedAccouchement(Ok(#(new_profil, new_accouchement))) -> {
      #(model, {
        case new_profil {
          Some(new_profil) ->
            effect.batch([
              submit_profil(model.pb, new_profil, ApiReturnedProfil),
              submit_accouchement(model.pb, new_accouchement),
            ])
          None -> submit_accouchement(model.pb, new_accouchement)
        }
      })
    }
    UserSubmittedAccouchement(Error(_)) -> todo
    ApiReturnedAccouchement(Ok(_accouchement)) -> todo
    ApiReturnedAccouchement(Error(_)) -> todo
    UserClickedLogout -> {
      todo
      // #(
      //   effect.map(pb.logout(), PocketBaseMsg),
      // )
    }

    PocketBaseMsg(pb.LoggedIn) -> #(
      Model(..model, page: AccueilPage),
      get_profil(model.pb, ApiReturnedProfil),
    )
    PocketBaseMsg(pb_msg) -> {
      let #(pb, effect) = pb.update(model.pb, pb_msg, pb.default_error_handler)
      #(Model(..model, pb:), effect.map(effect, PocketBaseMsg))
    }
    UserClickedDock(location) -> {
      let page = case location {
        "Accouchement" -> {
          let user_id = case model.pb.auth {
            Some(auth) -> auth.user_id
            None -> todo
          }
          let profil = case model.profil.sexe, model.profil.semestre {
            Some(sexe), Some(semestre) -> None
            sexe, semestre -> Some(Profil(name: None, sexe:, semestre:))
          }
          AccouchementPage(#(profil, empty_accouchement(user_id)))
        }
        "Profil" -> ProfilPage
        "Accueil" -> AccueilPage
        _ -> model.page
      }
      let model = Model(..model, page:)
      #(model, effect.none())
    }
    ApiReturnedProfil(Ok(new_profil)) -> {
      #(Model(..model, profil: new_profil), effect.none())
    }
    ApiReturnedProfil(Error(_)) -> todo
    UserSubmittedProfil(Ok(profil)) -> #(
      model,
      submit_profil(model.pb, profil, ApiReturnedProfil),
    )
    UserSubmittedProfil(Error(_)) -> todo
    UserChangedSexe(_) -> todo
    UserChangedSemestre(_) -> todo
    UserChangedPosteChef(_) -> todo
    UserChangedMoment(_) -> todo
    UserChangedInstrument(_) -> todo
    UserChangedRaison(_) -> todo
    UserChangedRaisonAutre(_) -> todo
  }
}

fn get_profil(server: PocketBase, msg) {
  let user_id = case server.auth {
    Some(auth) -> auth.user_id
    None -> ""
  }
  pb.get_one_record(server, "users", user_id, decode_profil(), msg)
}

fn submit_profil(server: PocketBase, profil: Profil, msg) {
  let user_id = case server.auth {
    Some(auth) -> auth.user_id
    None -> ""
  }
  pb.update_one_record(
    server,
    "users",
    user_id,
    encode_profil(profil),
    decode_profil(),
    msg,
  )
}

fn submit_accouchement(pb: PocketBase, acc: Accouchement) -> Effect(Msg) {
  pb.create_one_record(
    pb,
    "accouchements",
    encode_accouchement(acc),
    decode_accouchement(),
    ApiReturnedAccouchement,
  )
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  let page = model.page
  case page {
    ProfilPage ->
      view_profil(model.profil)
      |> base_view(page)
    LoginPage -> view_login()
    AccouchementPage(#(profil, acc)) ->
      view_accouchement(profil, acc)
      |> base_view(page)
    AccueilPage ->
      view_accueil()
      |> base_view(page)
  }
}

fn base_view(inner: Element(Msg), page: Page) -> Element(Msg) {
  let buttons = [
    #("Accueil", icons.home_icon()),
    #("Accouchement", icons.baby_icon()),
    #("Profil", icons.user_icon()),
  ]
  html.div([attribute.class("min-h-full mx-auto bg-base-100")], [
    nav_bar(),
    html.div([attribute.class("px-4 py-8 mx-auto max-w-[100rem]")], [inner]),
    components.render_dock(
      buttons:,
      active_page: page_name(page),
      on_click: UserClickedDock,
    ),
  ])
}

fn nav_bar() {
  html.div([attribute.class("navbar bg-base-200 shadow-sm")], [
    html.div([attribute.class("navbar-start")], []),
    html.div([attribute.class("navbar-center")], [html.text("Test")]),
    html.div([attribute.class("navbar-end")], []),
  ])
}

fn view_profil(profil: Profil) -> Element(Msg) {
  html.div([attribute.class("")], [
    html.main([attribute.class("")], [view_profil_form(profil)]),
    html.button([attribute.class("btn"), event.on_click(UserClickedLogout)], [
      html.text("Se déconnecter"),
    ]),
  ])
}

fn fieldset_sexe(checked: String) {
  components.RadioFieldSet(
    name: "sexe",
    legend: "Êtes-vous … ?",
    choices: [
      #("femme", html.text("Une femme")),
      #("homme", html.text("Un homme")),
    ],
    checked:,
    on_change: Some(UserChangedSexe),
  )
  |> components.render_radio_fieldset()
}

fn fieldset_semestre(checked: String) {
  components.RadioFieldSet(
    name: "semestre",
    legend: "En quel semestre êtes-vous ?",
    choices: [
      #("ps", html.text("Phase socle")),
      #("pa2", html.text("Phase d’approfondissement : 2ème année")),
      #("pa3", html.text("Phase d’approfondissement : 3ème année")),
      #("pa4", html.text("Phase d’approfondissement : 4ème année")),
      #("dj1", html.text("Docteur junior : 1ère année")),
      #("dj2", html.text("Docteur junior : 2ème année")),
    ],
    checked:,
    on_change: Some(UserChangedSemestre),
  )
  |> components.render_radio_fieldset()
}

fn fieldset_poste_chef(checked: String) {
  components.RadioFieldSet(
    name: "poste_chef",
    legend: "Quel poste occupe le chef ?",
    choices: [
      #("ph", html.text("Practicien Hospitalier")),
      #("assistant", html.text("Assistant")),
      #("dj", html.text("Docteur Junior")),
    ],
    checked:,
    on_change: Some(UserChangedPosteChef),
  )
  |> components.render_radio_fieldset()
}

fn fieldset_moment(checked: String) {
  components.RadioFieldSet(
    name: "moment",
    legend: "A quel moment de la journée a eu lieu l’accouchement ?",
    choices: [
      #("journee_semaine", html.text("Jour de semaine, 8h-18h")),
      #("journee_weekend", html.text("Jour de week-end, 8h-18h")),
      #("debut_nuit", html.text("18h-minuit")),
      #("fin_nuit", html.text("minuit-8h")),
    ],
    checked:,
    on_change: Some(UserChangedMoment),
  )
  |> components.render_radio_fieldset()
}

fn fieldset_instrument(checked: String) {
  components.RadioFieldSet(
    name: "instrument",
    legend: "Quel instrument a permis l’accouchement ?",
    choices: [
      #("ventouse", html.text("Ventouse")),
      #("forceps", html.text("Forceps")),
      #("spatule", html.text("Spatule")),
    ],
    checked:,
    on_change: Some(UserChangedInstrument),
  )
  |> components.render_radio_fieldset()
}

fn fieldset_autonomie(checked: String) {
  components.RadioFieldSet(
    name: "autonomie",
    legend: "Avec quel niveau d’autonomie l’interne a-t-il/elle réalisé l’accouchement ?",
    choices: [
      #(
        "observe",
        html.text(
          "Il/elle a uniquement observé – Le chef a réalisé le geste pendant que l’interne observait",
        ),
      ),
      #(
        "aide_active",
        html.text(
          "Il/elle a participé avec une aide active – L’interne fait avec le chef (nécessité d’une grande d’aide)",
        ),
      ),
      #(
        "aide_mineure",
        html.text(
          "Il/elle a eu une aide mineure  - le chef aide l’interne avec un minimum d’intervention nécessaire",
        ),
      ),
      #(
        "sans_aide",
        html.text(
          "Il/elle a pratiqué en autonomie – L’interne a réalisé le geste seul(e), sous observation passive du chef",
        ),
      ),
    ],
    checked:,
    on_change: Some(UserChangedAutonomie),
  )
  |> components.render_radio_fieldset()
}

fn fieldset_autonomie_raison_observe(
  checked: String,
  other_is_disabled: Bool,
  other_value: String,
) {
  components.RadioFieldSet(
    name: "autonomie_raison",
    legend: "Quelle est la principale raison pour laquelle l’interne n’a pas pu réalisé le geste ?",
    choices: [
      #("geste_difficile", html.text("Le geste était difficile")),
      #(
        "situation_urgence",
        html.text("Nous étions dans une situation d’urgence"),
      ),
      #("manque_confiance", html.text("Manque de confiance envers l’interne")),
      #("changement_instrument", html.text("Changement d’instrument")),
      #(
        "cas_particulier",
        html.text("Cas particulier : Patiente suivie par le chef / V.I.P"),
      ),
      #(
        "autre",
        components.render_autre_input_field(
          is_disabled: other_is_disabled,
          value: other_value,
          on_input: Some(UserChangedRaisonAutre),
        ),
      ),
    ],
    checked:,
    on_change: Some(UserChangedRaison),
  )
  |> components.render_radio_fieldset()
}

fn fieldset_autonomie_raison_aide_active(
  checked: String,
  other_is_disabled: Bool,
  other_value: String,
) {
  components.RadioFieldSet(
    name: "autonomie_raison",
    legend: "Pourquoi avez-vous estimé nécessaire d’aider activement l’interne ?",
    choices: [
      #(
        "guidance_technique",
        html.text("Le geste nécessitait une guidance technique"),
      ),
      #(
        "manque_experience",
        html.text("L’interne manquait d’expérience sur ce geste"),
      ),
      #("changement_instrument", html.text("Changement d’instrument")),
      #(
        "execution_rapide",
        html.text("La situation nécessitait une exécution rapide"),
      ),
      #(
        "autre",
        components.render_autre_input_field(
          is_disabled: other_is_disabled,
          value: other_value,
          on_input: Some(UserChangedRaisonAutre),
        ),
      ),
    ],
    checked:,
    on_change: Some(UserChangedRaison),
  )
  |> components.render_radio_fieldset()
}

fn fieldset_autonomie_raison_aide_mineure(
  checked: String,
  other_is_disabled: Bool,
  other_value: String,
) {
  components.RadioFieldSet(
    name: "autonomie_raison",
    legend: "Pourquoi avez-vous choisi de laisser l’interne avec une aide mineure ?",
    choices: [
      #(
        "niveau_interne",
        html.text(
          "Niveau de l’interne compatible avec le fait de laisser faire",
        ),
      ),
      #(
        "environnement_favorable",
        html.text(
          "L’environnement était favorable à l’apprentissage (temps / contexte)",
        ),
      ),
      #(
        "gestes_interne",
        html.text(
          "Gestes de l’interne compatible avec une aide à minima jusqu’à la fin",
        ),
      ),
      #(
        "autre",
        components.render_autre_input_field(
          is_disabled: other_is_disabled,
          value: other_value,
          on_input: Some(UserChangedRaisonAutre),
        ),
      ),
    ],
    checked:,
    on_change: Some(UserChangedRaison),
  )
  |> components.render_radio_fieldset()
}

fn view_profil_form(profil: Profil) -> Element(Msg) {
  let handle_submit = fn(form_data) {
    form.decoding({
      use sexe <- form.parameter
      use semestre <- form.parameter

      Profil(
        name: None,
        sexe: string.to_option(sexe),
        semestre: string.to_option(semestre),
      )
    })
    |> form.with_values(form_data)
    |> form.field("sexe", form.string)
    |> form.field("semestre", form.string)
    |> form.finish
    |> UserSubmittedProfil()
  }
  let sexe = option.unwrap(profil.sexe, "")
  let semestre = option.unwrap(profil.semestre, "")

  html.form([event.on_submit(handle_submit), attribute.class("")], [
    fieldset_sexe(sexe),
    fieldset_semestre(semestre),
    html.button([attribute.class("btn"), attribute.type_("submit")], [
      html.text("Enregistrer"),
    ]),
  ])
}

fn view_login() -> Element(Msg) {
  login_form()
}

fn login_form() -> Element(Msg) {
  let handle_submit = fn(form_data) {
    form.decoding({
      use username <- form.parameter
      use password <- form.parameter

      LoginData(username:, password:)
    })
    |> form.with_values(form_data)
    |> form.field("username", form.string |> form.and(form.must_not_be_empty))
    |> form.field(
      "password",
      form.string |> form.and(form.must_be_string_longer_than(8)),
    )
    |> form.finish
    |> UserSubmittedLoginForm
  }

  html.form([event.on_submit(handle_submit)], [
    html.fieldset(
      [
        attribute.class(
          "fieldset bg-base-200 border-base-300 rounded-box w-xs border p-4",
        ),
      ],
      [
        html.legend([attribute.class("fieldset-legend")], [html.text("Login")]),
        html.label([attribute.class("label")], [html.text("Username")]),
        html.input([
          attribute.class("input"),
          attribute.placeholder("Username"),
          attribute.name("username"),
          attribute.type_("text"),
        ]),
        html.label([attribute.class("label")], [html.text("Password")]),
        html.input([
          attribute.class("input"),
          attribute.placeholder("Password"),
          attribute.name("password"),
          attribute.type_("password"),
        ]),
        html.button([attribute.class("btn")], [html.text("Login")]),
      ],
    ),
  ])
}

fn view_accueil() {
  html.div([attribute.class("stats shadow ")], [
    html.div([attribute.class("stat")], [
      html.div([attribute.class("stat-title")], [html.text("Total Page Views")]),
      html.div([attribute.class("stat-value")], [html.text("89,400")]),
      html.div([attribute.class("stat-desc")], [
        html.text("21% more than last month"),
      ]),
    ]),
  ])
}

fn view_accouchement(profil: Option(Profil), acc: Accouchement) -> Element(Msg) {
  let validate_profil = fn() {
    Ok(Profil(name: None, sexe: Some("homme"), semestre: Some("pa2")))
  }
  let handle_submit = fn() -> Msg {
    let accouchement_form = validate_accouchement(acc)
    case profil {
      Some(_) -> {
        case validate_profil(), accouchement_form {
          Ok(profil_form), Ok(accouchement) ->
            Ok(#(Some(profil_form), accouchement))
          _, _ -> Error(Nil)
        }
      }
      None -> {
        case accouchement_form {
          Ok(accouchement) -> Ok(#(None, accouchement))
          Error(_) -> Error(Nil)
        }
      }
    }
    |> UserSubmittedAccouchement
  }
  let raison_radio_checked = case acc.raison {
    RaisonProposee(raison) -> raison
    RaisonLibre(_raison) -> "autre"
    RaisonNone -> ""
  }
  let raison_other_is_disabled = case acc.raison {
    RaisonProposee(_raison) -> True
    RaisonLibre(_raison) -> False
    RaisonNone -> True
  }
  let raison_other_input_value = case acc.raison {
    RaisonLibre(raison) -> raison
    _ -> ""
  }

  let questions = case acc.autonomie {
    Some("observe") -> [
      fieldset_autonomie_raison_observe(
        raison_radio_checked,
        raison_other_is_disabled,
        raison_other_input_value,
      ),
    ]
    Some("aide_active") -> [
      fieldset_autonomie_raison_aide_active(
        raison_radio_checked,
        raison_other_is_disabled,
        raison_other_input_value,
      ),
    ]
    Some("aide_mineure") -> [
      fieldset_autonomie_raison_aide_mineure(
        raison_radio_checked,
        raison_other_is_disabled,
        raison_other_input_value,
      ),
    ]
    _ -> []
  }

  let questions = [
    fieldset_poste_chef(option.unwrap(acc.poste_chef, "")),
    fieldset_moment(option.unwrap(acc.moment, "")),
    fieldset_instrument(option.unwrap(acc.instrument, "")),
    fieldset_autonomie(option.unwrap(acc.autonomie, "")),
    ..questions
  ]

  let questions = case profil {
    Some(profil) -> {
      [
        fieldset_sexe(option.unwrap(profil.semestre, "")),
        fieldset_semestre(option.unwrap(profil.sexe, "")),
        ..questions
      ]
    }
    None -> questions
  }

  html.form(
    [attribute.class(""), event.on_click(handle_submit())],
    list.flatten([
      questions,
      [html.button([attribute.class("btn")], [html.text("Enregistrer")])],
    ]),
  )
}
