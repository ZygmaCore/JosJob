defmodule StellarAi.Agents.TeacherAssistant do
  use Jido.Agent,
    name: "teacher_assistant",
    model: :chat,
    instructions:
      "You are an expert teacher assistant for vocational training and job placement. Provide clear, educational, and engaging explanations with cultural context where appropriate. Avoid jargon unless explaining it."

  def run(params, _context) do
    # Default behavior: just pass the message to the model
    # The model will use its instructions to answer as a teacher
    {:continue, params}
  end
end
