import accouchement.{type Accouchement} as acc
import components
import fieldsets
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
        acc.Accouchement(
          ..acc,
          autonomie: Some(new_autonomie),
          raison: acc.RaisonNone,
        )
      #(
        Model(..model, page: AccouchementPage(#(profil, new_acc))),
        effect.none(),
      )
    }
    UserChangedRaison("autre") -> {
      let assert AccouchementPage(#(profil, acc)) = model.page
      let new_acc = acc.Accouchement(..acc, raison: acc.RaisonLibre(""))
      #(
        Model(..model, page: AccouchementPage(#(profil, new_acc))),
        effect.none(),
      )
    }
    UserChangedRaison(raison) -> {
      let assert AccouchementPage(#(profil, acc)) = model.page
      let new_acc = acc.Accouchement(..acc, raison: acc.RaisonProposee(raison))
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
          AccouchementPage(#(profil, acc.empty(user_id)))
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
    acc.encode(acc),
    acc.decode(),
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
    fieldsets.sexe(sexe, Some(UserChangedSexe)),
    fieldsets.semestre(semestre, Some(UserChangedSemestre)),
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
    let accouchement_form = acc.validate(acc)
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

  let raison_params =
    fieldsets.RaisonFieldSetParams(
      radio_checked: case acc.raison {
        acc.RaisonProposee(raison) -> raison
        acc.RaisonLibre(_raison) -> "autre"
        acc.RaisonNone -> ""
      },
      on_radio_change: Some(UserChangedRaison),
      input_is_disabled: case acc.raison {
        acc.RaisonProposee(_raison) -> True
        acc.RaisonLibre(_raison) -> False
        acc.RaisonNone -> True
      },
      input_value: case acc.raison {
        acc.RaisonLibre(raison) -> raison
        _ -> ""
      },
      on_input_change: Some(UserChangedRaisonAutre),
    )

  let questions = case acc.autonomie {
    Some("observe") -> [fieldsets.raison_observe(raison_params)]
    Some("aide_active") -> [fieldsets.raison_aide_active(raison_params)]
    Some("aide_mineure") -> [fieldsets.raison_aide_mineure(raison_params)]
    _ -> []
  }

  let questions = [
    fieldsets.poste_chef(
      option.unwrap(acc.poste_chef, ""),
      Some(UserChangedPosteChef),
    ),
    fieldsets.moment(option.unwrap(acc.moment, ""), Some(UserChangedMoment)),
    fieldsets.instrument(
      option.unwrap(acc.instrument, ""),
      Some(UserChangedInstrument),
    ),
    fieldsets.autonomie(
      option.unwrap(acc.autonomie, ""),
      Some(UserChangedAutonomie),
    ),
    ..questions
  ]

  let questions = case profil {
    Some(profil) -> {
      [
        fieldsets.sexe(
          option.unwrap(profil.semestre, ""),
          Some(UserChangedSexe),
        ),
        fieldsets.semestre(
          option.unwrap(profil.sexe, ""),
          Some(UserChangedSemestre),
        ),
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
