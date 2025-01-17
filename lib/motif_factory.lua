local MotifFactory = {}
function MotifFactory.create(notes, engine)
  return Motif.new({notes = notes, engine = engine})
end
return MotifFactory 