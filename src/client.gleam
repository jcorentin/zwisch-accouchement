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
  AccouchementPage(AccouchementFormState)
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

type SomeAutonomieRaisonState {
  Proposed(String)
  Other(String)
}

type AutonomieRaisonState =
  Option(SomeAutonomieRaisonState)

fn encode_autonomie_raison(raison: AutonomieRaisonState) {
  case raison {
    Some(Proposed(choice)) -> choice
    Some(Other(choice)) -> choice
    None -> ""
  }
}

type AccouchementFormState {
  AccouchementFormState(
    profil: Option(Profil),
    poste_chef: String,
    moment: String,
    instrument: String,
    autonomie: String,
    raison: AutonomieRaisonState,
  )
}

fn empty_form_state() {
  AccouchementFormState(
    profil: None,
    poste_chef: "",
    moment: "",
    instrument: "",
    autonomie: "",
    raison: None,
  )
}

pub type Accouchement {
  Accouchement(
    poste_chef: String,
    moment: String,
    instrument: String,
    autonomie: String,
    raison: String,
  )
}

pub fn decode_accouchement() {
  use poste_chef <- decode.field("poste_chef", decode.string)
  use moment <- decode.field("moment", decode.string)
  use instrument <- decode.field("instrument", decode.string)
  use autonomie <- decode.field("autonomie", decode.string)
  use autonomie_raison <- decode.field("autonomie_raison", decode.string)
  decode.success(Accouchement(
    poste_chef: poste_chef,
    moment: moment,
    instrument: instrument,
    autonomie: autonomie,
    raison: autonomie_raison,
  ))
}

pub fn encode_accouchement(user_id: String, accouchement: Accouchement) {
  json.object([
    #("user", json.string(user_id)),
    #("poste_chef", json.string(accouchement.poste_chef)),
    #("moment", json.string(accouchement.moment)),
    #("instrument", json.string(accouchement.instrument)),
    #("autonomie", json.string(accouchement.autonomie)),
    #("autonomie_raison", json.string(accouchement.raison)),
  ])
  |> json.to_string()
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
  UserSubmittedProfilForm(Result(Profil, form.Form))
  ApiReturnedProfil(Result(Profil, rsvp.Error))
  UserSubmittedAccouchementForm(Result(#(Option(Profil), Accouchement), Nil))
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
      let assert AccouchementPage(form_state) = model.page
      let new_accouchement =
        AccouchementFormState(
          ..form_state,
          autonomie: new_autonomie,
          raison: None,
        )
      #(Model(..model, page: AccouchementPage(new_accouchement)), effect.none())
    }
    UserChangedRaison("autre") -> {
      let assert AccouchementPage(form_state) = model.page
      let new_accouchement =
        AccouchementFormState(..form_state, raison: Some(Other("")))
      #(Model(..model, page: AccouchementPage(new_accouchement)), effect.none())
    }
    UserChangedRaison(raison) -> {
      let assert AccouchementPage(form_state) = model.page
      let new_accouchement =
        AccouchementFormState(..form_state, raison: Some(Proposed(raison)))
      #(Model(..model, page: AccouchementPage(new_accouchement)), effect.none())
    }

    UserSubmittedAccouchementForm(Ok(#(new_profil, new_accouchement))) -> {
      #(model, {
        case new_profil {
          Some(new_profil) ->
            effect.batch([
              update_profil(model.pb, new_profil, ApiReturnedProfil),
              create_record(model.pb, new_accouchement),
            ])
          None -> create_record(model.pb, new_accouchement)
        }
      })
    }
    UserSubmittedAccouchementForm(Error(_)) -> todo
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
      let page = case model.page, location {
        _, "Accouchement" -> AccouchementPage(empty_form_state())
        _, "Profil" -> ProfilPage
        _, "Accueil" -> AccueilPage
        _, _ -> model.page
      }
      let model = Model(..model, page:)
      #(model, effect.none())
    }
    ApiReturnedProfil(Ok(new_profil)) -> {
      #(Model(..model, profil: new_profil), effect.none())
    }
    ApiReturnedProfil(Error(_)) -> todo
    UserSubmittedProfilForm(Ok(profil)) -> #(
      model,
      update_profil(model.pb, profil, ApiReturnedProfil),
    )
    UserSubmittedProfilForm(Error(_)) -> todo
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

fn update_profil(server: PocketBase, profil: Profil, msg) {
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

fn create_record(pb: PocketBase, accouchement) {
  let user_id = case pb.auth {
    Some(auth) -> auth.user_id
    option.None -> todo
  }
  pb.create_one_record(
    pb,
    "accouchements",
    encode_accouchement(user_id, accouchement),
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
    AccouchementPage(form_state) ->
      view_accouchement(form_state)
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
        "manque_expérience",
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
    |> UserSubmittedProfilForm()
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

fn view_accouchement(accouchement: AccouchementFormState) -> Element(Msg) {
  html.div([attribute.class("")], [main_form(accouchement)])
}

fn main_form(accouchement: AccouchementFormState) -> Element(Msg) {
  let validate_profil = fn() {
    Ok(Profil(name: None, sexe: Some("homme"), semestre: Some("pa2")))
  }
  let validate_accouchement = fn() {
    Ok(Accouchement(
      poste_chef: accouchement.poste_chef,
      moment: accouchement.moment,
      instrument: accouchement.instrument,
      autonomie: accouchement.autonomie,
      raison: encode_autonomie_raison(accouchement.raison),
    ))
  }
  let handle_submit = fn() -> Msg {
    let accouchement_form = validate_accouchement()
    case accouchement.profil {
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
    |> UserSubmittedAccouchementForm
  }
  let raison_radio_checked = case accouchement.raison {
    Some(Proposed(raison)) -> raison
    Some(Other(_raison)) -> "autre"
    None -> ""
  }
  let raison_other_is_disabled = case accouchement.raison {
    Some(Proposed(_raison)) -> True
    Some(Other(_raison)) -> False
    None -> True
  }
  let raison_other_input_value = case accouchement.raison {
    Some(Other(raison)) -> raison
    _ -> ""
  }

  let questions = case accouchement.autonomie {
    "observe" -> [
      fieldset_autonomie_raison_observe(
        raison_radio_checked,
        raison_other_is_disabled,
        raison_other_input_value,
      ),
    ]
    "aide_active" -> [
      fieldset_autonomie_raison_aide_active(
        raison_radio_checked,
        raison_other_is_disabled,
        raison_other_input_value,
      ),
    ]
    "aide_mineure" -> [
      fieldset_autonomie_raison_aide_mineure(
        raison_radio_checked,
        raison_other_is_disabled,
        raison_other_input_value,
      ),
    ]
    _ -> []
  }

  let questions = [
    fieldset_poste_chef(accouchement.poste_chef),
    fieldset_moment(accouchement.moment),
    fieldset_instrument(accouchement.instrument),
    fieldset_autonomie(accouchement.autonomie),
    ..questions
  ]

  let questions = case accouchement.profil {
    Some(profil) -> {
      let checked_semestre = option.unwrap(profil.semestre, "")
      let checked_sexe = option.unwrap(profil.sexe, "")
      [
        fieldset_sexe(checked_sexe),
        fieldset_semestre(checked_semestre),
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
