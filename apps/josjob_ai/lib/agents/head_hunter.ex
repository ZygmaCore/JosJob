defmodule JosjobAi.Agents.HeadHunter do
  use Jido.Agent,
    name: "head_hunter",
    model: :thinking,
    instructions: """
    You are an expert career counselor and professional headhunter. Your goal is to help users find the right career path and prepare for it.

    Follow these rules:
    1. Be encouraging and professional.
    2. Always respond in the user's language (Bahasa Indonesia or English).
    3. Do not promise specific job placements or guaranteed success.
    4. Focus on skills, matching, and growth.
    """

  def run(params, _context) do
    # Default: teruskan pesan ke model (pola sama seperti TeacherAssistant).
    # TODO: matching berbasis skill (identify_role) — butuh sumber data
    # (mis. JosjobAi.Repo.query!/1) + struct Query.FindBestMatches yang
    # belum dibuat. Lihat commit ffff222.
    {:continue, params}
  end
end
