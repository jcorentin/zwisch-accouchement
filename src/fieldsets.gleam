import components
import gleam/list
import gleam/option.{type Option}
import lustre/element.{type Element}
import lustre/element/html

pub type RaisonFieldSetParams(a) {
  RaisonFieldSetParams(
    radio_checked: String,
    on_radio_change: Option(fn(String) -> a),
    input_is_disabled: Bool,
    input_value: String,
    on_input_change: Option(fn(String) -> a),
  )
}

pub fn sexe(
  checked checked: String,
  on_change on_change: Option(fn(String) -> a),
) -> Element(a) {
  components.RadioFieldSet(
    name: "sexe",
    legend: "Êtes-vous … ?",
    choices: [
      #("femme", html.text("Une femme")),
      #("homme", html.text("Un homme")),
    ],
    checked:,
    on_change:,
  )
  |> components.render_radio_fieldset()
}

pub fn semestre(
  checked checked: String,
  on_change on_change: Option(fn(String) -> a),
) -> Element(a) {
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
    on_change:,
  )
  |> components.render_radio_fieldset()
}

pub fn poste_chef(
  checked checked: String,
  on_change on_change: Option(fn(String) -> a),
) -> Element(a) {
  components.RadioFieldSet(
    name: "poste_chef",
    legend: "Quel poste occupe le chef ?",
    choices: [
      #("ph", html.text("Practicien Hospitalier")),
      #("assistant", html.text("Assistant")),
      #("dj", html.text("Docteur Junior")),
    ],
    checked:,
    on_change:,
  )
  |> components.render_radio_fieldset()
}

pub fn moment(
  checked checked: String,
  on_change on_change: Option(fn(String) -> a),
) -> Element(a) {
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
    on_change:,
  )
  |> components.render_radio_fieldset()
}

pub fn instrument(
  checked checked: String,
  on_change on_change: Option(fn(String) -> a),
) -> Element(a) {
  components.RadioFieldSet(
    name: "instrument",
    legend: "Quel instrument a permis l’accouchement ?",
    choices: [
      #("ventouse", html.text("Ventouse")),
      #("forceps", html.text("Forceps")),
      #("spatule", html.text("Spatule")),
    ],
    checked:,
    on_change:,
  )
  |> components.render_radio_fieldset()
}

pub fn autonomie(
  checked checked: String,
  on_change on_change: Option(fn(String) -> a),
) -> Element(a) {
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
    on_change:,
  )
  |> components.render_radio_fieldset()
}

pub fn raison_observe(params: RaisonFieldSetParams(a)) -> Element(a) {
  let base = base_autonomie_raison(params)
  components.RadioFieldSet(
    ..base,
    name: "autonomie_raison",
    legend: "Quelle est la principale raison pour laquelle l’interne n’a pas pu réalisé le geste ?",
    choices: list.append(
      [
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
      ],
      base.choices,
    ),
  )
  |> components.render_radio_fieldset()
}

pub fn raison_aide_active(params: RaisonFieldSetParams(a)) -> Element(a) {
  let base = base_autonomie_raison(params)
  components.RadioFieldSet(
    ..base,
    name: "autonomie_raison",
    legend: "Pourquoi avez-vous estimé nécessaire d’aider activement l’interne ?",
    choices: list.append(
      [
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
            is_disabled: params.input_is_disabled,
            value: params.input_value,
            on_input: params.on_input_change,
          ),
        ),
      ],
      base.choices,
    ),
  )
  |> components.render_radio_fieldset()
}

pub fn raison_aide_mineure(params: RaisonFieldSetParams(a)) -> Element(a) {
  let base = base_autonomie_raison(params)
  components.RadioFieldSet(
    ..base,
    name: "autonomie_raison",
    legend: "Pourquoi avez-vous choisi de laisser l’interne avec une aide mineure ?",
    choices: list.append(
      [
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
      ],
      base.choices,
    ),
  )
  |> components.render_radio_fieldset()
}

fn base_autonomie_raison(params: RaisonFieldSetParams(a)) {
  components.RadioFieldSet(
    name: "",
    legend: "",
    choices: [
      #(
        "autre",
        components.render_autre_input_field(
          is_disabled: params.input_is_disabled,
          value: params.input_value,
          on_input: params.on_input_change,
        ),
      ),
    ],
    checked: params.radio_checked,
    on_change: params.on_radio_change,
  )
}
