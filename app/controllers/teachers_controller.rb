# author: Kevin M, Tommy B
# Teacher methods, as well as admin, super, and home stuff.
class TeachersController < ApplicationController
  
  include TeachersHelper
  #Before actions to reduce access and prime pages to show teacher info.
  before_action :set_teacher, only: [:show, :edit, :update, :destroy]
  before_action :same_school, only: [:show, :edit, :update, :destroy]
  before_action :is_admin, except: [:home, :update, :edit, :edit_password, :update_password]
  before_action :is_super, except: [:home, :update, :edit, :edit_password, :update_password]

  # GET /teachers
  # This method prepares the index view. It sets up pagination in an ascending
  # order by their screen_name.
  def index
    @current_teacher = current_teacher
    # For testing only
    # @current_school = School.find(1)
    @current_school = School.find(@current_teacher.school_id)
    
    @teachers = Teacher.where(school_id: @current_teacher.school_id).paginate(page: params[:page], :per_page => 10)
    @teachers = @teachers.order('screen_name ASC')
  end
  
  # GET /admin_report
  #This method prepares the admin_report view.
  def admin_report
    @current_teacher = current_teacher
    @students = Student.where(school_id: current_teacher.school_id)
    @teachers = Teacher.where(school_id: current_teacher.school_id)
    @squares = Square.where(school_id: current_teacher.school_id)
  end
  
  # GET /teachers/1
  # This prepares the roster view for the teacher. It sets up pagination similarly
  # to the teacher index.
  def show
    @teacher = Teacher.find(params[:id])
    @students = @teacher.students
    @all_students_at_school = Student.where(school_id: @teacher.school_id)
    @students_not_in_roster_but_at_school = Student.where(school_id: @teacher.school_id).where.not(id: @teacher.students)
    @students_not_in_roster_but_at_school = @students_not_in_roster_but_at_school.order('screen_name ASC')
    
    if params[:add_student]
      @teacher.students << Student.find(params[:add_student_id])
    elsif params[:remove_student]
      @teacher.students.delete(Student.find(params[:remove_student_id]))
    end
  end
  
  # GET /teachers/id/login_settings
  def login_settings
    @teacher = Teacher.find(params[:id])
  end

  # GET /teachers/new
  # This prepares the new teacher form.
  def new
    @teacher = Teacher.new
  end

  # GET /teachers/1/edit
  # If the user viewing a profile isn't an admin, then it shows them their own
  # profile instead.
  def edit
    if !is_admin?
      @teacher = @current_teacher
      params[:id] = @teacher.id
    end
  end
  
  # GET /admin
  # This prepares the admin dashboard.
  def admin
    @teacher = current_teacher
  end 
  
  # GET /teachers/password
  # This prepares the password change page. It will always show the current user's,
  # even if they try to access it with another ID via /teachers/id/edit_password.
  #utilized http://stackoverflow.com/questions/25490308/ruby-on-rails-two-different-edit-pages-and-forms-how-to for help
  def edit_password
    @teacher = current_teacher
  end
  
  #utilized http://stackoverflow.com/questions/25490308/ruby-on-rails-two-different-edit-pages-and-forms-how-to for help
  # This updates the Teacher's password.
  def update_password
    teacher = current_teacher
    if teacher and teacher.authenticate(params[:old_password])
      if params[:password] == params[:password_confirmation]
        teacher.password = BCrypt::Password.create(params[:password])
        if teacher.save!
          redirect_to @teacher, :flash => { :notice => "Password changed." }
        end
      else
        redirect_to @teacher, :flash => { :danger => "Incorrect Password." }
      end
    else
      redirect_to @teacher, :flash => { :danger => "Incorrect Password." }
    end
  end

  # POST /teachers
  # This creates a new Teacher. It's basically just scaffolding, but the redirect
  # has been changed.
  def create
    @teacher = Teacher.new(teacher_params)

    respond_to do |format|
      if @teacher.save
        format.html { redirect_to teachers_path, :flash => { :notice => "Teacher was successfully created." } }
      else
        format.html { render :new }
      end
    end
  end

  #author: Matthew O & Alex P
  #home page for teachers, display top 8 most used students, route to anaylze or new session
  def home
    @teacher = current_teacher
    @top_students = Student.where(id: Session.where(session_teacher: @teacher.id).group('session_student').order('count(*)').select('session_student').limit(8))
    if params[:start_session]
        @session = Session.new
        @session.session_teacher = @teacher.id
        @session.session_student = params[:student_id]
        respond_to do |format|
          if @session.save
            format.html { redirect_to @session, :flash => { :notice => 'Session was successfully created.' } }
          else
            format.html { render :new }
          end
        end
    elsif params[:analyze]
        redirect_to analysis_student_path(params[:student_id])
    end
  end
  
  
  # PATCH/PUT /teachers/1
  # This updates a teacher. If current_password is in the params, then they're
  # trying to change their password, so it redirects the put to change_password.
  #
  # Similarly, if suspended is in the params, then it changes their success or
  # error redirection.
  def update
    if params[:teacher][:current_password]
      change_password
    elsif params[:teacher][:suspended]
      change_login_settings
    else
      respond_to do |format|
        if @teacher.update(teacher_params)
          format.html { redirect_to edit_teacher_path(@teacher.id), :flash => { :notice => 'Teacher was successfully updated.' } }
        else
          format.html { render :edit }
        end
      end
    end
  end
  
  # This method displays flashes for updates to login settings. It's virtually
  # identical to update, but it redirects to a different location with a different
  # flash.
  def change_login_settings
    respond_to do |format|
      if @teacher.update(teacher_params)
        format.html { redirect_to edit_teacher_path(@teacher.id), :flash => { :notice => 'Login settings for this teacher were successully updated.' } }
      else
        format.html { render :login_settings }
      end
    end
  end
  
  # This method changes the Teacher's password and displays appropriate flashes.
  # Used http://stackoverflow.com/questions/25490308/ruby-on-rails-two-different-edit-pages-and-forms-how-to for help
  # for method layout.
  def change_password
    teacher = current_teacher
    if teacher.authenticate(params[:teacher][:current_password])
      if params[:teacher][:password] == params[:teacher][:password_confirmation]
        teacher.password = params[:teacher][:password]
        if teacher.save!
          redirect_to edit_teacher_path(teacher), :flash => { :notice => "Password changed." }
        end
      else
        redirect_to edit_password_teacher_path, :flash => { :error => "New password and confirmation didn't match." }
      end
    else
      redirect_to edit_password_teacher_path, :flash => { :error => "Incorrect password." }
    end
  end
   
  # This method prepares the super view.
  def super
    @schools = School.all
  end
  
   #Robert Herrera
   # POST /super
   # This changes the super school focus.
  def updateFocus
    teacher = Teacher.find(1)
    schoolName = params[full_name]
    teacher.full_name = schoolName
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_teacher
      @teacher = Teacher.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def teacher_params
      params.require(:teacher).permit(:user_name, :last_login,
      :full_name, :screen_name, :icon, :color, :email, :description, :powers, 
      :school_id, :password, :password_confirmation, :suspended, :current_password)
    end
    
    #Can only access teachers and info from the same school
    def same_school
      if current_teacher.school_id != Teacher.find(params[:id]).school_id
        redirect_to home_path, :flash => { :notice => "You can't access other schools." }
      end
    end
    
    # Switching the focus school 
    def focus_school_params 
      params.require(:full_name).permit(:school_id)
    end 
end
