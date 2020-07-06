class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :edit, :update, :destroy]

  # GET /projects
  # GET /projects.json
  def index
    @projects = Project.where(section_id: params[:section_id])
    @manual_assignment = Project.manual_assignment
  end

  # GET /projects/1
  # GET /projects/1.json
  def show
    @students = Student.where(project_id: params[:id])
  end

  # GET /projects/new
  def new
    @all_project_tags = Project.all_project_tags

    @project = Project.new
  end

  # GET /projects/1/edit
  def edit
    @all_project_tags = Project.all_project_tags
    @topics = @project.topics
    @client = @project.client
  end

  # POST /projects
  # POST /projects.json
  def create
    # Add selected tags to the topics variable of a project
    if !params[:tags].nil?
      session[:tags] = params[:tags]
    end

    if !session[:tags].nil? && params[:tags].nil?
      new_hash = {}
      new_hash[:tags] = session[:tags]
      redirect_to new_section_project(new_hash)
    end

    @selected_tags = params[:tags] if params.key?(:tags)

    if @selected_tags != nil
      params[:project].merge!(:topics => @selected_tags.join(','))
    end

    @project = Project.new(project_params)
    @project.section_id = params[:section_id]

    respond_to do |format|
      if @project.save
        format.html { redirect_to section_projects_path, notice: 'Project was successfully created.' }
        format.json { render :show, status: :created, location: @project }
      else
        format.html { render :new }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /projects/1
  # PATCH/PUT /projects/1.json
  def update
    # Add selected tags to the topics variable of a project
    @selected_tags = params[:tags] if params.key?(:tags)

    if @selected_tags != nil
      params[:project].merge!(:topics => @selected_tags.join(','))
    end

    respond_to do |format|
      if @project.update(project_params)
        format.html { redirect_to section_projects_path(:section_id => @project.section_id), notice: 'Project was successfully updated.' }
        format.json { render :show, status: :ok, location: @project }
      else
        format.html { render :edit }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/1
  # DELETE /projects/1.json
  def destroy
    @project.destroy
    respond_to do |format|
      format.html { redirect_to section_projects_path, notice: 'Project was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def match
    students = Student.where(section_id: params[:section_id])
    projects = Project.where(section_id: params[:section_id])

    student_scores_hash = {}

    students.each do |student|
      student_scores_hash[student.id] = {}
      student_project_ratings = student.preferences.split(',')
      student_interests = student.topics.split(',')
      student_electives = student.electives.split(',')

      student_project_ratings.each do |p|
        preference_parse  = p.split('.')
        project_id = preference_parse[0].to_i
        rating  = preference_parse[1].to_i
        score = 0
        case rating
        when 5
          score = 50
        when 4
          score = 30
        when 3
          score = 10
        end
        project = Project.find(project_id)
        project_topics = project.topics.split(',')
        score += (student_interests & project_topics).length()*10
        elective_map = Student.electiveMap
        tags = []
        student_electives.each do |e|
          tags << elective_map[e].split(',')
        end
        tags = tags.flatten.uniq
        intersecting_electives = tags & project.topics.split(',')
        score += intersecting_electives.length()*5 
        student_scores_hash[student.id][project_id] = score
      end

    end
    average_score_hash = Hash.new
    student_scores_hash.each do |student,values|
      scores = values.values
      avg = scores.sum/scores.size
      average_score_hash[student] = avg
    end
    average_score_hash = average_score_hash.sort_by{|k, v| v}.to_h
    #puts average_score_hash
    #puts student_mean_scores.join(' ')
    print_student_scores(student_scores_hash)

    assignment_hash = {}
    projects.each do |project|
      assignment_hash[project.id] = {}
    end

    average_score_hash.each do |student_id|
      student_scores_hash.each do |student|
        if(student[0] == student_id[0])
          score_hash = student[1]
          assignment = score_hash.max_by{|k,v| v}
          assignment_hash[assignment[0]].merge!({student[0] => assignment[1]})
        end
      end
    end
    total_score = calculate_total_score(assignment_hash)



    print_assignment_hash(assignment_hash)
    puts "Total score: " + total_score.to_s

    puts "\n--------------------------------------------------------------------------------\n"

    
    assignment_hash.each do |project_id,student_assignments|
      project = Project.find(project_id)
      if(student_assignments.size < project.min_group_size)
        
      end
    end
    assignment_hash = swap_students(17,14,student_scores_hash,assignment_hash)
    total_score = calculate_total_score(assignment_hash)

    print_assignment_hash(assignment_hash)
    puts "Total score: " + total_score.to_s

    redirect_to section_projects_path

  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_project
      @project = Project.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def project_params
      params.require(:project).permit(:title, :description, :max_group_size, :min_group_size, :topics, :hardware, :industry_sponsored, :client, :tutorial)
    end
    
    def print_student_scores(hash)
      hash.each do |student,project_scores|
        puts "Student: " + student.to_s + " " + project_scores.to_s
      end
    end

    def print_assignment_hash(hash)
      hash.each do |project,students|
        puts "Project: " + project.to_s + " " + students.to_s + " " + calculate_project_score(students).to_s
      end
    end
    
    def calculate_project_score(hash)
      if(hash.empty?)
        return 0
      else
        return hash.values.sum
      end
    end
    
    def calculate_total_score(hash)
      score = 0
      hash.each do |project,students|
        p = Project.find(project)
        if(students.size < p.min_group_size || students.size > p.max_group_size)
          score += 0
        else
          score += calculate_project_score(students)
        end
      end
      return score
    end

    def swap_students(student1, student2, scores_hash, assignment_hash)
      project1_id = 0
      project2_id = 0
      assignment_hash.each do |key,value|
        if(value.key?(student1))
          project1_id = key
        elsif(value.key?(student2))
          project2_id = key
        end
      end
      puts "Student: " + student1.to_s + " From: " + project1_id.to_s
      puts "Student: " + student2.to_s + " From: " + project2_id.to_s
      new_student1_score = scores_hash[student1][project2_id]
      new_student2_score = scores_hash[student2][project1_id]
      if(new_student1_score == nil || new_student2_score == nil)
        return assignment_hash
      end
      assignment_hash[project1_id].delete(student1)
      assignment_hash[project1_id].merge!({student2 => new_student2_score})
      assignment_hash[project2_id].delete(student2)
      assignment_hash[project2_id].merge!({student1 => new_student1_score})
      return assignment_hash
    end

end

